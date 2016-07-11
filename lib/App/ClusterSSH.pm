package App::ClusterSSH;

use 5.008.004;
use warnings;
use strict;
use version; our $VERSION = version->new('4.08_01');

use Carp qw/cluck :DEFAULT/;

use base qw/ App::ClusterSSH::Base /;
use App::ClusterSSH::Host;
use App::ClusterSSH::Config;
use App::ClusterSSH::Helper;
use App::ClusterSSH::Cluster;
use App::ClusterSSH::Getopt;

use FindBin qw($Script);

use POSIX ":sys_wait_h";
use POSIX qw/:sys_wait_h strftime mkfifo/;
use File::Temp qw/:POSIX/;
use Fcntl;
use Tk 800.022;
use Tk::Xlib;
use Tk::ROText;
require Tk::Dialog;
require Tk::LabEntry;
use X11::Protocol;
use X11::Protocol::Constants qw/ Shift Mod5 ShiftMask /;
use X11::Protocol::WM;
use vars qw/ %keysymtocode %keycodetosym /;
use X11::Keysyms '%keysymtocode', 'MISCELLANY', 'XKB_KEYS', '3270', 'LATIN1',
    'LATIN2', 'LATIN3', 'LATIN4', 'KATAKANA', 'ARABIC', 'CYRILLIC', 'GREEK',
    'TECHNICAL', 'SPECIAL', 'PUBLISHING', 'APL', 'HEBREW', 'THAI', 'KOREAN';
use File::Basename;
use Module::Load;
use Net::hostent;
use Sys::Hostname;
use English;
use Socket;
use File::Path qw(make_path);

# Notes on general order of processing
#
# parse cmd line options for extra config files
# load system configuration files
# load cfg files from options
# overlay rest of cmd line args onto options
# record all clusters
# parse given tags/hostnames and resolve to connections
# open terminals
# optionally open console if required

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{cluster} = App::ClusterSSH::Cluster->new( parent => $self, );
    $self->{options} = App::ClusterSSH::Getopt->new( parent => $self, );
    $self->{config}  = App::ClusterSSH::Config->new( parent => $self, );
    $self->{helper}  = App::ClusterSSH::Helper->new( parent => $self, );

    $self->set_config( $self->config );

    # catch and reap any zombies
    $SIG{CHLD} = sub {
        my $kid;
        do {
            $kid = waitpid( -1, WNOHANG );
            $self->debug( 2, "REAPER currently returns: $kid" );
        } until ( $kid == -1 || $kid == 0 );
    };

    return $self;
}

sub config {
    my ($self) = @_;
    return $self->{config};
}

sub cluster {
    my ($self) = @_;
    return $self->{cluster};
}

sub helper {
    my ($self) = @_;
    return $self->{helper};
}

sub options {
    my ($self) = @_;
    return $self->{options};
}

sub getopts {
    my ($self) = @_;
    return $self->options->getopts;
}

sub add_option {
    my ( $self, %args ) = @_;
    return $self->{options}->add_option(%args);
}

my %windows;    # hash for all window definitions
my %menus;      # hash for all menu definitions
my @servers;    # array of servers provided on cmdline
my %servers;    # hash of server cx info
my $xdisplay;
my %keyboardmap;
my $sysconfigdir = "/etc";
my %ssh_hostnames;
my $host_menu_static_items;    # number of items in the host menu that should
                               # not be touched by build_host_menu
my (@dead_hosts);              # list of hosts whose sessions are now closed
my $sort = sub { sort @_ };   # reference to our sort function which may later
                              # be changed in run() if the user has asked for
                              # natural sorting

$keysymtocode{unknown_sym} = 0xFFFFFF;    # put in a default "unknown" entry
$keysymtocode{EuroSign}
    = 0x20AC;    # Euro sign - missing from X11::Protocol::Keysyms

# and also map it the other way
%keycodetosym = reverse %keysymtocode;

# Set up UTF-8 on STDOUT
binmode STDOUT, ":utf8";

#use bytes;

### all sub-routines ###

# Pick a color based on a string.
sub pick_color {
    my ($string)   = @_;
    my @components = qw(AA BB CC EE);
    my $color      = 0;
    for ( my $i = 0; $i < length($string); $i++ ) {
        $color += ord( substr( $string, $i, 1 ) );
    }

    srand($color);
    my $ans = '\\#';
    $ans .= $components[ int( 4 * rand() ) ];
    $ans .= $components[ int( 4 * rand() ) ];
    $ans .= $components[ int( 4 * rand() ) ];
    return $ans;
}

# close a specific host session
sub terminate_host($) {
    my ( $self, $svr ) = @_;
    $self->debug( 2, "Killing session for $svr" );
    if ( !$servers{$svr} ) {
        $self->debug( 2, "Session for $svr not found" );
        return;
    }

    $self->debug( 2, "Killing process $servers{$svr}{pid}" );
    kill( 9, $servers{$svr}{pid} ) if kill( 0, $servers{$svr}{pid} );
    delete( $servers{$svr} );
    return $self;
}

# catch_all exit routine that should always be used
sub exit_prog() {
    my ($self) = @_;
    $self->debug( 3, "Exiting via normal routine" );

    # for each of the client windows, send a kill.
    # to make sure we catch all children, even when they haven't
    # finished starting or received the kill signal, do it like this
    while (%servers) {
        foreach my $svr ( keys(%servers) ) {
            $self->terminate_host($svr);
        }
    }
    exit 0;
}

sub evaluate_commands {
    my ($self) = @_;
    my ( $return, $user, $port, $host );

    # break apart the given host string to check for user or port configs
    my $evaluate = $self->options->evaluate;
    print "{evaluate}=", $evaluate, "\n";
    $user = $1 if ( ${evaluate} =~ s/^(.*)@// );
    $port = $1 if ( ${evaluate} =~ s/:(\w+)$// );
    $host = ${evaluate};

    $user = $user ? "-l $user" : "";
    if ( $self->config->{comms} eq "telnet" ) {
        $port = $port ? " $port" : "";
    }
    else {
        $port = $port ? "-p $port" : "";
    }

    print STDERR "Testing terminal - running command:\n";

    my $command = "$^X -e 'print \"Base terminal test\n\"; sleep 2'";

    my $terminal_command = join( ' ',
        $self->config->{terminal},
        $self->config->{terminal_allow_send_events}, "-e " );

    my $run_command = "$terminal_command $command";

    print STDERR $run_command, $/;

    system($run_command);
    print STDERR "\nTesting comms - running command:\n";

    my $comms_command = join( ' ',
        $self->config->{ $self->config->{comms} },
        $self->config->{ $self->config->{comms} . "_args" } );

    if ( $self->config->{comms} eq "telnet" ) {
        $comms_command .= " $host $port";
    }
    else {
        $comms_command
            .= " $user $port $host hostname ; echo Got hostname via ssh; sleep 2";
    }

    print STDERR $comms_command, $/;

    system($comms_command);

    $run_command = "$terminal_command '$comms_command'";
    print STDERR $run_command, $/;

    system($run_command);

    $self->exit_prog;
}

sub load_keyboard_map() {
    my ($self) = @_;

    # load up the keyboard map to convert keysyms to keyboardmap
    my $min      = $xdisplay->{min_keycode};
    my $count    = $xdisplay->{max_keycode} - $min;
    my @keyboard = $xdisplay->GetKeyboardMapping( $min, $count );

    # @keyboard arry
    #  0 = plain key
    #  1 = with shift
    #  2 = with Alt-GR
    #  3 = with shift + AltGr
    #  4 = same as 2 - control/alt?
    #  5 = same as 3 - shift-control-alt?

    $self->debug( 1, "Loading keymaps and keycodes" );

    my %keyboard_modifier_priority = (
        'sa' => 3,    # lowest
        'a'  => 2,
        's'  => 1,
        'n'  => 0,    # highest
    );

    my %keyboard_stringlike_modifiers = reverse %keyboard_modifier_priority;

  # try to associate $keyboard=X11->GetKeyboardMapping table with X11::Keysyms
    foreach my $i ( 0 .. $#keyboard ) {
        for my $modifier ( 0 .. 3 ) {
            if (   defined( $keyboard[$i][$modifier] )
                && defined( $keycodetosym{ $keyboard[$i][$modifier] } ) )
            {

                # keyboard layout contains the keycode at $modifier level
                if (defined(
                        $keyboardmap{ $keycodetosym{ $keyboard[$i][$modifier]
                        } }
                    )
                    )
                {

# we already have a mapping, let's see whether current one is better (lower shift state)
                    my ( $mod_code, $key_code )
                        = $keyboardmap{ $keycodetosym{ $keyboard[$i]
                                [$modifier] } } =~ /^(\D+)(\d+)$/;

      # it is not easy to get around our own alien logic storing modifiers ;-)
                    if ( $modifier < $keyboard_modifier_priority{$mod_code} )
                    {

                     # YES! current keycode have priority over old one (phew!)
                        $keyboardmap{ $keycodetosym{ $keyboard[$i][$modifier]
                                } }
                            = $keyboard_stringlike_modifiers{$modifier}
                            . ( $i + $min );
                    }
                }
                else {

                    # we don't yet have a mapping... piece of cake!
                    $keyboardmap{ $keycodetosym{ $keyboard[$i][$modifier] } }
                        = $keyboard_stringlike_modifiers{$modifier}
                        . ( $i + $min );
                }
            }
            else {

                # we didn't get the code from X11::Keysyms
                if ( defined( $keyboard[$i][$modifier] )
                    && $keyboard[$i][$modifier] != 0 )
                {

                    # ignore code=0
                    $self->debug(
                        2,
                        "Unknown keycode ",
                        $keyboard[$i][$modifier]
                    );
                }
            }
        }
    }

    # don't know these two key combs yet...
    #$keyboardmap{ $keycodetosym { $keyboard[$_][4] } } = $_ + $min;
    #$keyboardmap{ $keycodetosym { $keyboard[$_][5] } } = $_ + $min;

    #print "$_ => $keyboardmap{$_}\n" foreach(sort(keys(%keyboardmap)));
    #print "keysymtocode: $keysymtocode{o}\n";
    #die;
}

sub get_keycode_state($) {
    my ( $self, $keysym ) = @_;
    $keyboardmap{$keysym} =~ m/^(\D+)(\d+)$/;
    my ( $state, $code ) = ( $1, $2 );

    $self->debug( 2, "keyboardmap=:", $keyboardmap{$keysym}, ":" );
    $self->debug( 2, "state=$state, code=$code" );

SWITCH: for ($state) {
        /^n$/ && do {
            $state = 0;
            last SWITCH;
        };
        /^s$/ && do {
            $state = Shift();
            last SWITCH;
        };
        /^a$/ && do {
            $state = Mod5();
            last SWITCH;
        };
        /^sa$/ && do {
            $state = Shift() + Mod5();
            last SWITCH;
        };

        die("Should never reach here");
    }

    $self->debug( 2, "returning state=:$state: code=:$code:" );

    return ( $state, $code );
}

sub resolve_names(@) {
    my ( $self, @servers ) = @_;
    $self->debug( 2, 'Resolving cluster names: started' );

    foreach (@servers) {
        my $dirty    = $_;
        my $username = q{};
        $self->debug( 3, 'Checking tag ', $_ );

        if ( $dirty =~ s/^(.*)@// ) {
            $username = $1;
        }

        my @tag_list = $self->cluster->get_tag($dirty);

        if (   $self->config->{use_all_a_records}
            && $dirty !~ m/^(\d{1,3}\.?){4}$/
            && !@tag_list )
        {
            my $hostobj = gethostbyname($dirty);
            if ( defined($hostobj) ) {
                my @alladdrs = map { inet_ntoa($_) } @{ $hostobj->addr_list };
                $self->cluster->register_tag( $dirty, @alladdrs );
                if ( $#alladdrs > 0 ) {
                    $self->debug( 3, 'Expanded to ',
                        join( ' ', $self->cluster->get_tag($dirty) ) );
                    @tag_list = $self->cluster->get_tag($dirty);
                }
                else {
                    # don't expand if there is only one record found
                    $self->debug( 3, 'Only one A record' );
                }
            }
        }
        if (@tag_list) {
            $self->debug( 3, '... it is a cluster' );
            foreach my $node (@tag_list) {
                if ($username) {
                    $node =~ s/^(.*)@//;
                    $node = $username . '@' . $node;
                }
                push( @servers, $node );
            }
            $_ = q{};
        }
    }

    # now run everything through the external command, if one is defined
    if ( $self->config->{external_cluster_command} ) {
        $self->debug( 4, 'External cluster command defined' );

        # use a second array here in case of failure so previously worked
        # out entries are not lost
        my @new_servers;
        eval {
            @new_servers = $self->cluster->get_external_clusters(@servers);
        };

        if ($@) {
            warn $@, $/;
        }
        else {
            @servers = @new_servers;
        }
    }

    # now clean the array up
    @servers = grep { $_ !~ m/^$/ } @servers;

    if ( $self->config->{unique_servers} ) {
        $self->debug( 3, 'removing duplicate server names' );
        @servers = remove_repeated_servers(@servers);
    }

    $self->debug( 3, 'leaving with ', $_ ) foreach (@servers);
    $self->debug( 2, 'Resolving cluster names: completed' );
    return (@servers);
}

sub remove_repeated_servers {
    my %all = ();
    @all{@_} = 1;
    return ( keys %all );
}

sub change_main_window_title() {
    my ($self) = @_;
    my $number = keys(%servers);
    $windows{main_window}->title( $self->config->{title} . " [$number]" );
}

sub show_history() {
    my ($self) = @_;
    if ( $self->config->{show_history} ) {
        $windows{history}->packForget();
        $windows{history}->selectAll();
        $windows{history}->deleteSelected();
        $self->config->{show_history} = 0;
    }
    else {
        $windows{history}->pack(
            -fill   => "x",
            -expand => 1,
        );
        $self->config->{show_history} = 1;
    }
}

sub update_display_text($) {
    my ( $self, $char ) = @_;

    return if ( !$self->config->{show_history} );

    $self->debug( 2, "Dropping :$char: into display" );

SWITCH: {
        foreach ($char) {
            /^Return$/ && do {
                $windows{history}->insert( 'end', "\n" );
                last SWITCH;
            };

            /^BackSpace$/ && do {
                $windows{history}->delete('end - 2 chars');
                last SWITCH;
            };

            /^(:?Shift|Control|Alt)_(:?R|L)$/ && do {
                last SWITCH;
            };

            length($char) > 1 && do {
                $windows{history}
                    ->insert( 'end', chr( $keysymtocode{$char} ) )
                    if ( $keysymtocode{$char} );
                last SWITCH;
            };

            do {
                $windows{history}->insert( 'end', $char );
                last SWITCH;
            };
        }
    }
    return $self;
}

sub substitute_macros {
    my ( $self, $svr, $text ) = @_;

    return $text unless ( $self->config->{macros_enabled} eq 'yes' );

    {
        my $macro_servername = $self->config->{macro_servername};
        ( my $servername = $svr ) =~ s/\s+//;
        $text =~ s!$macro_servername!$servername!xsmg;
    }
    {
        my $macro_hostname = $self->config->{macro_hostname};
        my $hostname       = $servers{$svr}{givenname};
        $text =~ s!$macro_hostname!$hostname!xsmg;
    }
    {
        my $macro_username = $self->config->{macro_username};
        my $username       = $servers{$svr}{username};
        $username ||= getpwuid($UID);
        $text =~ s!$macro_username!$username!xsmg;
    }
    {
        my $macro_newline = $self->config->{macro_newline};
        $text =~ s!$macro_newline!\n!xsmg;
    }
    {
        my $macro_version = $self->config->{macro_version};
        $text =~ s/$macro_version/$VERSION/xsmg;
    }

    return $text;
}

sub send_text($@) {
    my $self = shift;
    my $svr  = shift;
    my $text = join( "", @_ );

    $self->debug( 2, "servers{$svr}{wid}=$servers{$svr}{wid}" );
    $self->debug( 3, "Sending to '$svr' text:$text:" );

    $text = $self->substitute_macros( $svr, $text );

    foreach my $char ( split( //, $text ) ) {
        next if ( !defined($char) );
        my $ord = ord($char);
        $ord = 65293 if ( $ord == 10 );    # convert 'Return' to sym

        if ( !defined( $keycodetosym{$ord} ) ) {
            warn("Unknown character in xmodmap keytable: $char ($ord)\n");
            next;
        }
        my $keysym  = $keycodetosym{$ord};
        my $keycode = $keysymtocode{$keysym};

        $self->debug( 2, "Looking for char :$char: with ord :$ord:" );
        $self->debug( 2, "Looking for keycode :$keycode:" );
        $self->debug( 2, "Looking for keysym  :$keysym:" );
        $self->debug( 2, "Looking for keyboardmap :",
            $keyboardmap{$keysym}, ":" );
        my ( $state, $code ) = $self->get_keycode_state($keysym);
        $self->debug( 2, "Got state :$state: code :$code:" );

        for my $event (qw/KeyPress KeyRelease/) {
            $self->debug( 2,
                "sending event=$event code=:$code: state=:$state:" );
            $xdisplay->SendEvent(
                $servers{$svr}{wid},
                0,
                $xdisplay->pack_event_mask($event),
                $xdisplay->pack_event(
                    'name'        => $event,
                    'detail'      => $code,
                    'state'       => $state,
                    'event'       => $servers{$svr}{wid},
                    'root'        => $xdisplay->root(),
                    'same_screen' => 1,
                ),
            );
        }
    }
    $xdisplay->flush();
}

sub send_text_to_all_servers {
    my $self = shift;
    my $text = join( '', @_ );

    foreach my $svr ( keys(%servers) ) {
        $self->send_text( $svr, $text )
            if ( $servers{$svr}{active} == 1 );
    }
}

sub send_variable_text_to_all_servers($&) {
    my ( $self, $code ) = @_;

    foreach my $svr ( keys(%servers) ) {
        $self->send_text( $svr, $code->($svr) )
            if ( $servers{$svr}{active} == 1 );
    }
}

sub send_resizemove($$$$$) {
    my ( $self, $win, $x_pos, $y_pos, $x_siz, $y_siz ) = @_;

    $self->debug( 3,
        "Moving window $win to x:$x_pos y:$y_pos (size x:$x_siz y:$y_siz)" );

#$self->debug( 2, "resize move normal: ", $xdisplay->atom('WM_NORMAL_HINTS') );
#$self->debug( 2, "resize move size:   ", $xdisplay->atom('WM_SIZE_HINTS') );

    # set the window to have "user" set size & position, rather than "program"
    $xdisplay->req(
        'ChangeProperty',
        $win,
        $xdisplay->atom('WM_NORMAL_HINTS'),
        $xdisplay->atom('WM_SIZE_HINTS'),
        32,
        'Replace',

        # create data struct on-the-fly to set bitwise flags
        pack( 'LLLLL' . 'x[L]' x 12, 1 | 2, $x_pos, $y_pos, $x_siz, $y_siz ),
    );

    $xdisplay->req(
        'ConfigureWindow',
        $win,
        'x'      => $x_pos,
        'y'      => $y_pos,
        'width'  => $x_siz,
        'height' => $y_siz,
    );

    #$xdisplay->flush(); # dont flush here, but after all tiling worked out
}

sub open_client_windows(@) {
    my $self = shift;
    foreach (@_) {
        next unless ($_);

        my $server_object = App::ClusterSSH::Host->parse_host_string($_);

        my $username = $server_object->get_username();
        $username = $self->config->{user}
            if ( !$username && $self->config->{user} );
        my $port = $server_object->get_port();
        $port = $self->config->{port} if ( $self->config->{port} );
        my $server = $server_object->get_hostname();
        my $master = $server_object->get_master();

        my $given_server_name = $server_object->get_hostname();

        # see if we can find the hostname - if not, drop it
        my $realname = $server_object->get_realname();
        if ( !$realname ) {
            my $text = "WARNING: '$_' unknown";

            if (%ssh_hostnames) {
                $text
                    .= " (unable to resolve and not in user ssh config file)";
            }

            warn( $text, $/ );

       #next;  # Debian bug 499935 - ignore warnings about hostname resolution
        }

        $self->debug( 3, "username=$username, server=$server, port=$port" );

        my $color = '';
        if ( $self->config->{terminal_colorize} ) {
            my $c = pick_color($server);
            if ( $self->config->{terminal_bg_style} eq 'dark' ) {
                $color = "-bg \\#000000 -fg $c";
            }
            else {
                $color = "-fg \\#000000 -bg $c";
            }
        }

        my $count = q{};
        while ( defined( $servers{ $server . q{ } . $count } ) ) {
            $count++;
        }
        $server .= q{ } . $count;

        $servers{$server}{connect_string} = $_;
        $servers{$server}{givenname}      = $given_server_name;
        $servers{$server}{realname}       = $realname;
        $servers{$server}{username}       = $self->config->{user};
        $servers{$server}{username}       = $username if ($username);
        $servers{$server}{username}       = $username || '';
        $servers{$server}{port}           = $port || '';
        $servers{$server}{master}         = $self->config->{mstr} || '';
        $servers{$server}{master}         = $master if ($master);

        $self->debug( 2, "Working on server $server for $_" );

        $servers{$server}{pipenm} = tmpnam();

        $self->debug( 2, "Set temp name to: $servers{$server}{pipenm}" );
        mkfifo( $servers{$server}{pipenm}, 0600 )
            or die("Cannot create pipe: $!");

       # NOTE: the PID is re-fetched from the xterm window (via helper_script)
       # later as it changes and we need an accurate PID as it is widely used
        $servers{$server}{pid} = fork();
        if ( !defined( $servers{$server}{pid} ) ) {
            die("Could not fork: $!");
        }

        if ( $servers{$server}{pid} == 0 ) {

          # this is the child
          # Since this is the child, we can mark any server unresolved without
          # affecting the main program
            $servers{$server}{realname} .= "==" if ( !$realname );

            # copy and amend the config provided to the helper script
            my $local_config = $self->config;
            $local_config->{command} = $self->substitute_macros( $server,
                $local_config->{command} );

            my $exec = join( ' ',
                $self->config->{terminal},
                $color,
                $self->config->{terminal_args},
                $self->config->{terminal_allow_send_events},
                $self->config->{terminal_title_opt},
                "'"
                    . $self->config->{title} . ': '
                    . $servers{$server}{connect_string} . "'",
                '-font ' . $self->config->{terminal_font},
                "-e " . $^X . ' -e ',
                "'" . $self->helper->script( $self->config ) . "'",
                " " . $servers{$server}{pipenm},
                " " . $servers{$server}{givenname},
                " '" . $servers{$server}{username} . "'",
                " '" . $servers{$server}{port} . "'",
                " '" . $servers{$server}{master} . "'",
            );
            $self->debug( 2, "Terminal exec line:\n$exec\n" );
            exec($exec) == 0 or warn("Failed: $!");
        }
    }

    # Now all the windows are open, get all their window IDs
    foreach my $server ( keys(%servers) ) {
        next if ( defined( $servers{$server}{active} ) );

        # sleep for a moment to give system time to come up
        select( undef, undef, undef, 0.1 );

        # block on open so we get the text when it comes in
        unless (
            sysopen(
                $servers{$server}{pipehl}, $servers{$server}{pipenm},
                O_RDONLY
            )
            )
        {
            warn(
                "Cannot open pipe for reading when talking to $server: $!\n");
        }
        else {

            # NOTE: read both the xterm pid and the window ID here
            # get PID here as it changes from the fork above, and we need the
            # correct PID
            $self->debug( 2, "Performing sysread" );
            my $piperead;
            sysread( $servers{$server}{pipehl}, $piperead, 100 );
            ( $servers{$server}{pid}, $servers{$server}{wid} )
                = split( /:/, $piperead, 2 );
            warn("Cannot determ pid of '$server' window\n")
                unless $servers{$server}{pid};
            warn("Cannot determ window ID of '$server' window\n")
                unless $servers{$server}{wid};
            $self->debug( 2, "Done and closing pipe" );

            close( $servers{$server}{pipehl} );
        }
        delete( $servers{$server}{pipehl} );

        unlink( $servers{$server}{pipenm} );
        delete( $servers{$server}{pipenm} );

        $servers{$server}{active} = 1;    # mark as active
        $self->config->{internal_activate_autoquit}
            = 1;                          # activate auto_quit if in use
    }
    $self->debug( 2, "All client windows opened" );
    $self->config->{internal_total} = int( keys(%servers) );

    return $self;
}

sub get_font_size() {
    my ($self) = @_;
    $self->debug( 2, "Fetching font size" );

    # get atom name<->number relations
    my $quad_width = $xdisplay->atom("QUAD_WIDTH");
    my $pixel_size = $xdisplay->atom("PIXEL_SIZE");

    my $font          = $xdisplay->new_rsrc;
    my $terminal_font = $self->config->{terminal_font};
    $xdisplay->OpenFont( $font, $terminal_font );

    my %font_info;

    eval { (%font_info) = $xdisplay->QueryFont($font); }
        || die( "Fatal: Unrecognised font used ($terminal_font).\n"
            . "Please amend \$HOME/.clusterssh/config with a valid font (see man page).\n"
        );

    $self->config->{internal_font_width}
        = $font_info{properties}{$quad_width};
    $self->config->{internal_font_height}
        = $font_info{properties}{$pixel_size};

    if (   !$self->config->{internal_font_width}
        || !$self->config->{internal_font_height} )
    {
        die(      "Fatal: Unrecognised font used ($terminal_font).\n"
                . "Please amend \$HOME/.clusterssh/config with a valid font (see man page).\n"
        );
    }

    $self->debug( 2, "Done with font size" );
    return $self;
}

sub show_console() {
    my ($self) = shift;
    $self->debug( 2, "Sending console to front" );

    $self->config->{internal_previous_state} = "mid-change";

    # fudge the counter to drop a redraw event;
    $self->config->{internal_map_count} -= 4;

    $xdisplay->flush();
    $windows{main_window}->update();

    select( undef, undef, undef, 0.2 );    #sleep for a mo
    $windows{main_window}->withdraw;

    # Sleep for a moment to give WM time to bring console back
    select( undef, undef, undef, 0.5 );

    if ( $self->config->{menu_send_autotearoff} ) {
        $menus{send}->menu->tearOffMenu()->raise;
    }

    if ( $self->config->{menu_host_autotearoff} ) {
        $menus{hosts}->menu->tearOffMenu()->raise;
    }

    $windows{main_window}->deiconify;
    $windows{main_window}->raise;
    $windows{main_window}->focus( -force );
    $windows{text_entry}->focus( -force );

    $self->config->{internal_previous_state} = "normal";

    # fvwm seems to need this (Debian #329440)
    $windows{main_window}->MapWindow;

    return $self;
}

# set the first argument to the second if the first is undefined
# the equivalent of //= but works in older Perls (e.g. 5.8)
sub slash_slash_equal(\$$) {

    if (! defined(${$_[0]})) {
        ${$_[0]} = $_[1];
    }

    return ${$_[0]};
}

# leave function def open here so we can be flexible in how it's called
sub retile_hosts {
    my ( $self, $force ) = @_;
    $force ||= "";
    $self->debug( 2, "Retiling windows" );

    my %config;

    if ( $self->config->{window_tiling} ne "yes" && !$force ) {
        $self->debug( 3,
            "Not meant to be tiling; just reshow windows as they were" );

        foreach my $server ( reverse( keys(%servers) ) ) {
            $xdisplay->req( 'MapWindow', $servers{$server}{wid} );
        }
        $xdisplay->flush();
        $self->show_console();
        return;
    }

    # ALL SIZES SHOULD BE IN PIXELS for consistency

    $self->debug( 2, "Count is currently ", $self->config->{internal_total} );

    if ( $self->config->{internal_total} == 0 ) {

        # If nothing to tile, don't bother doing anything, just show console
        return $self->show_console();
    }

    # work out terminal pixel size from terminal size & font size
    # does not include any title bars or scroll bars - purely text area
    $self->config->{internal_terminal_cols}
        = ( $self->config->{terminal_size} =~ /(\d+)x.*/ )[0];
    $self->config->{internal_terminal_width}
        = (   $self->config->{internal_terminal_cols}
            * $self->config->{internal_font_width} )
        + $self->config->{terminal_decoration_width};

    $self->config->{internal_terminal_rows}
        = ( $self->config->{terminal_size} =~ /.*x(\d+)/ )[0];
    $self->config->{internal_terminal_height}
        = (   $self->config->{internal_terminal_rows}
            * $self->config->{internal_font_height} )
        + $self->config->{terminal_decoration_height};

    # fetch screen size
    $self->config->{internal_screen_height} = $xdisplay->{height_in_pixels};
    $self->config->{internal_screen_width}  = $xdisplay->{width_in_pixels};

    # Now, work out how many columns of terminals we can fit on screen
    $self->config->{internal_columns} = int(
        (         $self->config->{internal_screen_width}
                - $self->config->{screen_reserve_left}
                - $self->config->{screen_reserve_right}
        ) / (
            $self->config->{internal_terminal_width}
                + $self->config->{terminal_reserve_left}
                + $self->config->{terminal_reserve_right}
        )
    );

    # Work out the number of rows we need to use to fit everything on screen
    $self->config->{internal_rows} = int(
        (         $self->config->{internal_total}
                / $self->config->{internal_columns}
        ) + 0.999
    );

    $self->debug( 2, "Screen Columns: ", $self->config->{internal_columns} );
    $self->debug( 2, "Screen Rows: ",    $self->config->{internal_rows} );

    # Now adjust the height of the terminal to either the max given,
    # or to get everything on screen
    {
        my $height = int(
            (   (         $self->config->{internal_screen_height}
                        - $self->config->{screen_reserve_top}
                        - $self->config->{screen_reserve_bottom}
                ) - (
                    $self->config->{internal_rows} * (
                              $self->config->{terminal_reserve_top}
                            + $self->config->{terminal_reserve_bottom}
                    )
                )
            ) / $self->config->{internal_rows}
        );

        $self->debug( 2, "Terminal height=$height" );

        $self->config->{internal_terminal_height} = (
              $height > $self->config->{internal_terminal_height}
            ? $self->config->{internal_terminal_height}
            : $height
        );
    }

    $self->config->dump("noexit") if ( $self->options->debug > 1 );

    # now find the size of the window decorations
    if (! exists($self->config->{internal_terminal_wm_decoration_left})) {

        # use the first window as exemplary
        my($wid) = $servers{(keys(%servers))[0]}{wid};

        if (defined($wid)) {
            # get the WM decoration sizes
            ($self->config->{internal_terminal_wm_decoration_left},
                $self->config->{internal_terminal_wm_decoration_right},
                $self->config->{internal_terminal_wm_decoration_top},
                $self->config->{internal_terminal_wm_decoration_bottom}) =
                    X11::Protocol::WM::get_net_frame_extents($xdisplay, $wid);
        }

        # in case the WM call failed we set some defaults
        slash_slash_equal($self->config->{internal_terminal_wm_decoration_left}, 0);
        slash_slash_equal($self->config->{internal_terminal_wm_decoration_right}, 0);
        slash_slash_equal($self->config->{internal_terminal_wm_decoration_top}, 0);
        slash_slash_equal($self->config->{internal_terminal_wm_decoration_bottom}, 0);
    }

    # now we have the info, plot first window position
    my @hosts;
    my ( $current_x, $current_y, $current_row, $current_col ) = 0;
    if ( $self->config->{window_tiling_direction} =~ /right/i ) {
        $self->debug( 2, "Tiling top left going bot right" );
        @hosts     = $sort->( keys(%servers) );
        $current_x = $self->config->{screen_reserve_left}
            + $self->config->{terminal_reserve_left};
        $current_y = $self->config->{screen_reserve_top}
            + $self->config->{terminal_reserve_top};
        $current_row = 0;
        $current_col = 0;
    }
    else {
        $self->debug( 2, "Tiling bot right going top left" );
        @hosts = reverse( $sort->( keys(%servers) ) );
        $current_x
            = $self->config->{screen_reserve_right}
            - $self->config->{internal_screen_width}
            - $self->config->{terminal_reserve_right}
            - $self->config->{internal_terminal_width};
        $current_y
            = $self->config->{screen_reserve_bottom}
            - $self->config->{internal_screen_height}
            - $self->config->{terminal_reserve_bottom}
            - $self->config->{internal_terminal_height};

        $current_row = $self->config->{internal_rows} - 1;
        $current_col = $self->config->{internal_columns} - 1;
    }

    # Unmap windows (hide them)
    # Move windows to new locatation
    # Remap all windows in correct order
    foreach my $server (@hosts) {
        $self->debug( 3,
            "x:$current_x y:$current_y, r:$current_row c:$current_col" );

        # sf tracker 3061999
        # $xdisplay->req( 'UnmapWindow', $servers{$server}{wid} );

        if ( $self->config->{unmap_on_redraw} =~ /yes/i ) {
            $xdisplay->req( 'UnmapWindow', $servers{$server}{wid} );
        }

        $self->debug( 2, "Moving $server window" );
        $self->send_resizemove(
            $servers{$server}{wid},
            $current_x,
            $current_y,
            $self->config->{internal_terminal_width},
            $self->config->{internal_terminal_height}
        );

        $xdisplay->flush();
        select( undef, undef, undef, 0.1 );    # sleep for a moment for the WM

        if ( $self->config->{window_tiling_direction} =~ /right/i ) {

            # starting top left, and move right and down
            $current_x
                += $self->config->{terminal_reserve_left}
                + $self->config->{terminal_reserve_right}
                + $self->config->{internal_terminal_width}
                + $self->config->{internal_terminal_wm_decoration_left}
                + $self->config->{internal_terminal_wm_decoration_right};

            $current_col += 1;
            if ( $current_col == $self->config->{internal_columns} ) {
                $current_y
                    += $self->config->{terminal_reserve_top}
                    + $self->config->{terminal_reserve_bottom}
                    + $self->config->{internal_terminal_height}
                    + $self->config->{internal_terminal_wm_decoration_top}
                    + $self->config->{internal_terminal_wm_decoration_bottom};
                $current_x = $self->config->{screen_reserve_left}
                    + $self->config->{terminal_reserve_left};
                $current_row++;
                $current_col = 0;
            }
        }
        else {

            # starting bottom right, and move left and up

            $current_col -= 1;
            if ( $current_col < 0 ) {
                $current_row--;
                $current_col = $self->config->{internal_columns};
            }
        }
    }

    # Now remap in right order to get overlaps correct
    if ( $self->config->{window_tiling_direction} =~ /right/i ) {
        foreach my $server ( reverse(@hosts) ) {
            $self->debug( 2, "Setting focus on $server" );
            $xdisplay->req( 'MapWindow', $servers{$server}{wid} );

            # flush every time and wait a moment (The WMs are so slow...)
            $xdisplay->flush();
            select( undef, undef, undef, 0.1 );    # sleep for a mo
        }
    }
    else {
        foreach my $server (@hosts) {
            $self->debug( 2, "Setting focus on $server" );
            $xdisplay->req( 'MapWindow', $servers{$server}{wid} );

            # flush every time and wait a moment (The WMs are so slow...)
            $xdisplay->flush();
            select( undef, undef, undef, 0.1 );    # sleep for a mo
        }
    }

    # and as a last item, set focus back onto the console
    return $self->show_console();
}

sub capture_terminal() {
    my ($self) = @_;
    $self->debug( 0, "Stub for capturing a terminal window" );

    return if ( $self->coptions->debug < 6 );

    # should never see this - all experimental anyhow

    foreach my $server ( keys(%servers) ) {
        foreach my $data ( keys( %{ $servers{$server} } ) ) {
            print "server $server key $data is $servers{$server}{$data}\n";
        }
    }

    #return;

    my %atoms;

    for my $atom ( $xdisplay->req( 'ListProperties', $servers{loki}{wid} ) ) {
        $atoms{ $xdisplay->atom_name($atom) }
            = $xdisplay->req( 'GetProperty', $servers{loki}{wid},
            $atom, "AnyPropertyType", 0, 200, 0 );

        print $xdisplay->atom_name($atom), " ($atom) => ";
        print "join here\n";
        print join(
            "\n",
            $xdisplay->req(
                'GetProperty', $servers{loki}{wid},
                $atom, "AnyPropertyType", 0, 200, 0
            )
            ),
            "\n";
    }

    print "list by number\n";
    for my $atom ( 1 .. 90 ) {
        print "$atom: ", $xdisplay->req( 'GetAtomName', $atom ), "\n";
        print join(
            "\n",
            $xdisplay->req(
                'GetProperty', $servers{loki}{wid},
                $atom, "AnyPropertyType", 0, 200, 0
            )
            ),
            "\n";
    }
    print "\n";

    print "size hints\n";
    print join(
        "\n",
        $xdisplay->req(
            'GetProperty', $servers{loki}{wid},
            42, "AnyPropertyType", 0, 200, 0
        )
        ),
        "\n";

    print "atom list by name\n";
    foreach ( keys(%atoms) ) {
        print "atom :$_: = $atoms{$_}\n";
    }

    print "geom\n";
    print join " ", $xdisplay->req( 'GetGeometry', $servers{loki}{wid} ), $/;
    print "attrib\n";
    print join " ",
        $xdisplay->req( 'GetWindowAttributes', $servers{loki}{wid} ),
        $/;
}

sub toggle_active_state() {
    my ($self) = @_;
    $self->debug( 2, "Toggling active state of all hosts" );

    foreach my $svr ( sort( keys(%servers) ) ) {
        $servers{$svr}{active} = not $servers{$svr}{active};
    }
}

sub set_all_active() {
    my ($self) = @_;
    $self->debug( 2, "Setting all hosts to be active" );

    foreach my $svr ( keys(%servers) ) {
        $servers{$svr}{active} = 1;
    }

}

sub set_half_inactive() {
    my ($self) = @_;
    $self->debug( 2, "Setting approx half of all hosts to inactive" );

    my (@keys) = keys(%servers);
    $#keys /= 2;
    foreach my $svr (@keys) {
        $servers{$svr}{active} = 0;
    }
}

sub close_inactive_sessions() {
    my ($self) = @_;
    $self->debug( 2, "Closing all inactive sessions" );

    foreach my $svr ( sort( keys(%servers) ) ) {
        $self->terminate_host($svr) if ( !$servers{$svr}{active} );
    }
    $self->build_hosts_menu();
}

sub add_host_by_name() {
    my ($self) = @_;
    $self->debug( 2, "Adding host to menu here" );

    $windows{host_entry}->focus();
    my $answer = $windows{addhost}->Show();

    if ( !$answer || $answer ne "Add" ) {
        $menus{host_entry} = "";
        return;
    }

    if ( $menus{host_entry} ) {
        $self->debug( 2, "host=", $menus{host_entry} );
        my @names
            = $self->resolve_names( split( /\s+/, $menus{host_entry} ) );
        $self->debug( 0, 'Opening to: ', join( ' ', @names ) ) if (@names);
        $self->open_client_windows(@names);
    }

    if ( defined $menus{listbox} && $menus{listbox}->curselection() ) {
        my @hosts = $menus{listbox}->get( $menus{listbox}->curselection() );
        $self->debug( 2, "host=", join( ' ', @hosts ) );
        $self->open_client_windows( $self->resolve_names(@hosts) );
    }

    $self->build_hosts_menu();
    $menus{host_entry} = "";

    # retile, or bring console to front
    if ( $self->config->{window_tiling} eq "yes" ) {
        return $self->retile_hosts();
    }
    else {
        return $self->show_console();
    }
}

# attempt to re-add any hosts that have been closed since we started
# the session - either through errors or deliberate log-outs
sub re_add_closed_sessions() {
    my ($self) = @_;
    $self->debug( 2, "add closed sessions" );

    return if ( scalar(@dead_hosts) == 0 );

    my @new_hosts = @dead_hosts;

    # clear out the list in case open fails
    @dead_hosts = qw//;

    # try to open
    $self->open_client_windows(@new_hosts);

    # update hosts list with current state
    $self->build_hosts_menu();

    # retile, or bring console to front
    if ( $self->config->{window_tiling} eq "yes" ) {
        return $self->retile_hosts();
    }
    else {
        return $self->show_console();
    }
}

sub build_hosts_menu() {
    my ($self) = @_;
    $self->debug( 2, "Building hosts menu" );

    # first, empty the hosts menu from the last static entry + 1 on
    my $menu = $menus{bar}->entrycget( 'Hosts', -menu );
    $menu->delete( $host_menu_static_items, 'end' );

    $self->debug( 3, "Menu deleted" );

    # add back the separator
    $menus{hosts}->separator;

    $self->debug( 3, "Parsing list" );

    my $menu_item_counter = $host_menu_static_items;
    foreach my $svr ( $sort->( keys(%servers) ) ) {
        $self->debug( 3, "Checking $svr and restoring active value" );
        my $colbreak = 0;
        if ( $menu_item_counter > $self->config->{max_host_menu_items} ) {
            $colbreak          = 1;
            $menu_item_counter = 1;
        }
        $menus{hosts}->checkbutton(
            -label       => $svr,
            -variable    => \$servers{$svr}{active},
            -columnbreak => $colbreak,
        );
        $menu_item_counter++;
    }
    $self->debug( 3, "Changing window title" );
    $self->change_main_window_title();
    $self->debug( 2, "Done" );
}

sub setup_repeat() {
    my ($self) = @_;
    $self->config->{internal_count} = 0;

    # if this is too fast then we end up with queued invocations
    # with no time to run anything else
    $windows{main_window}->repeat(
        500,
        sub {
            $self->config->{internal_count} = 0
                if ( $self->config->{internal_count} > 60000 )
                ;    # reset if too high
            $self->config->{internal_count}++;
            my $build_menu = 0;
            $self->debug(
                5,
                "Running repeat;count=",
                $self->config->{internal_count}
            );

#$self->debug( 3, "Number of servers in hash is: ", scalar( keys(%servers) ) );

            foreach my $svr ( keys(%servers) ) {
                if ( defined( $servers{$svr}{pid} ) ) {
                    if ( !kill( 0, $servers{$svr}{pid} ) ) {
                        $build_menu = 1;
                        push( @dead_hosts, $servers{$svr}{givenname} );
                        delete( $servers{$svr} );
                        $self->debug( 0, "$svr session closed" );
                    }
                }
                else {
                    warn("Lost pid of $svr; deleting\n");
                    delete( $servers{$svr} );
                }
            }

            # get current number of clients
            $self->config->{internal_total} = int( keys(%servers) );

        #$self->debug( 3, "Number after tidy is: ", $config{internal_total} );

            # get current number of clients
            $self->config->{internal_total} = int( keys(%servers) );

        #$self->debug( 3, "Number after tidy is: ", $config{internal_total} );

            # If there are no hosts in the list and we are set to autoquit
            if (   $self->config->{internal_total} == 0
                && $self->config->{auto_quit} =~ /yes/i )
            {

                # and some clients were actually opened...
                if ( $self->config->{internal_activate_autoquit} ) {
                    $self->debug( 2, "Autoquitting" );
                    $self->exit_prog;
                }
            }

            # rebuild host menu if something has changed
            $self->build_hosts_menu() if ($build_menu);

            # clean out text area, anyhow
            $menus{entrytext} = "";

            #$self->debug( 3, "repeat completed" );
        }
    );
    $self->debug( 2, "Repeat setup" );

    return $self;
}

### Window and menu definitions ###

sub create_windows() {
    my ($self) = @_;
    $self->debug( 2, "create_windows: started" );
    $windows{main_window}
        = MainWindow->new( -title => "ClusterSSH", -class => 'cssh', );
    $windows{main_window}->withdraw;    # leave withdrawn until needed

    if ( defined( $self->config->{console_position} )
        && $self->config->{console_position} =~ /[+-]\d+[+-]\d+/ )
    {
        $windows{main_window}->geometry( $self->config->{console_position} );
    }

    $menus{entrytext}    = "";
    $windows{text_entry} = $windows{main_window}->Entry(
        -textvariable      => \$menus{entrytext},
        -insertborderwidth => 4,
        -width             => 25,
        -class             => 'cssh',
        )->pack(
        -fill   => "x",
        -expand => 1,
        );

    $windows{history} = $windows{main_window}->Scrolled(
        "ROText",
        -insertborderwidth => 4,
        -width             => $self->config->{history_width},
        -height            => $self->config->{history_height},
        -state             => 'normal',
        -takefocus         => 0,
        -class             => 'cssh',
    );
    $windows{history}->bindtags(undef);

    if ( $self->config->{show_history} ) {
        $windows{history}->pack(
            -fill   => "x",
            -expand => 1,
        );
    }

    $windows{main_window}->bind( '<Destroy>' => sub { $self->exit_prog } );

    # remove all Paste events so we set them up cleanly
    $windows{main_window}->eventDelete('<<Paste>>');

    # Set up paste events from scratch
    if ( $self->config->{key_paste} && $self->config->{key_paste} ne "null" )
    {
        $windows{main_window}->eventAdd(
            '<<Paste>>' => '<' . $self->config->{key_paste} . '>' );
    }

    if (   $self->config->{mouse_paste}
        && $self->config->{mouse_paste} ne "null" )
    {
        $windows{main_window}->eventAdd(
            '<<Paste>>' => '<' . $self->config->{mouse_paste} . '>' );
    }

    $windows{main_window}->bind(
        '<<Paste>>' => sub {
            $self->debug( 2, "PASTE EVENT" );

            $menus{entrytext} = "";
            my $paste_text = '';

            # SelectionGet is fatal if no selection is given
            Tk::catch {
                $paste_text = $windows{main_window}->SelectionGet;
            };

            if ( !length($paste_text) ) {
                warn("Got empty paste event\n");
                return;
            }

            $self->debug( 2, "Got text :", $paste_text, ":" );

            $self->update_display_text($paste_text);

            # now sent it on
            foreach my $svr ( keys(%servers) ) {
                $self->send_text( $svr, $paste_text )
                    if ( $servers{$svr}{active} == 1 );
            }
        }
    );

    $windows{help} = $windows{main_window}->Dialog(
        -popover    => $windows{main_window},
        -overanchor => "c",
        -popanchor  => "c",
        -class      => 'cssh',
        -font       => [
            -family => "interface system",
            -size   => 10,
        ],
        -text =>
            "Cluster Administrator Console using SSH\n\nVersion: $VERSION.\n\n"
            . "Bug/Suggestions to http://clusterssh.sf.net/",
    );

    $windows{manpage} = $windows{main_window}->DialogBox(
        -popanchor  => "c",
        -overanchor => "c",
        -title      => "Cssh Documentation",
        -buttons    => ['Close'],
        -class      => 'cssh',
    );

    my $manpage = `pod2text -l -q=\"\" $0 2>/dev/null`;
    if ( !$manpage ) {
        $manpage
            = "Help is missing.\nSee that command 'pod2text' is installed and in PATH.";
    }
    $windows{mantext}
        = $windows{manpage}->Scrolled( "Text", )->pack( -fill => 'both' );
    $windows{mantext}->insert( 'end', $manpage );
    $windows{mantext}->configure( -state => 'disabled' );

    $windows{addhost} = $windows{main_window}->DialogBox(
        -popover        => $windows{main_window},
        -popanchor      => 'n',
        -title          => "Add Host(s) or Cluster(s)",
        -buttons        => [ 'Add', 'Cancel' ],
        -default_button => 'Add',
        -class          => 'cssh',
    );

    my @tags = $self->cluster->list_tags();
    my @external_tags = map {"$_ *"} $self->cluster->list_external_clusters();
    push( @tags, @external_tags );

    if ( $self->config->{max_addhost_menu_cluster_items}
        && scalar @tags )
    {
        if ( scalar @tags < $self->config->{max_addhost_menu_cluster_items} )
        {
            $menus{listbox} = $windows{addhost}->Listbox(
                -selectmode => 'extended',
                -height     => scalar @tags,
                -class      => 'cssh',
            )->pack();
        }
        else {
            $menus{listbox} = $windows{addhost}->Scrolled(
                'Listbox',
                -scrollbars => 'e',
                -selectmode => 'extended',
                -height => $self->config->{max_addhost_menu_cluster_items},
                -class  => 'cssh',
            )->pack();
        }
        $menus{listbox}->insert( 'end', sort @tags );

        if (@external_tags) {
            $menus{addhost_text} = $windows{addhost}->add(
                'Label',
                -class => 'cssh',
                -text  => '* is external',
            )->pack();

            #$menus{addhost_text}->insert('end','lkjh lkjj sdfl jklsj dflj ');
        }
    }

    $windows{host_entry} = $windows{addhost}->add(
        'LabEntry',
        -textvariable => \$menus{host_entry},
        -width        => 20,
        -label        => 'Host',
        -labelPack    => [ -side => 'left', ],
        -class        => 'cssh',
    )->pack( -side => 'left' );
    $self->debug( 2, "create_windows: completed" );

    return $self;
}

sub capture_map_events() {
    my ($self) = @_;

    # pick up on console minimise/maximise events so we can do all windows
    $windows{main_window}->bind(
        '<Map>' => sub {
            $self->debug( 3, "Entering MAP" );

            my $state = $windows{main_window}->state();
            $self->debug(
                3,
                "state=$state previous=",
                $self->config->{internal_previous_state}
            );
            $self->debug( 3, "Entering MAP" );

            if ( $self->config->{internal_previous_state} eq $state ) {
                $self->debug( 3, "repeating the same" );
            }

            if ( $self->config->{internal_previous_state} eq "mid-change" ) {
                $self->debug( 3, "dropping out as mid-change" );
                return;
            }

            $self->debug(
                3,
                "state=$state previous=",
                $self->config->{internal_previous_state}
            );

            if ( $self->config->{internal_previous_state} eq "iconic" ) {
                $self->debug( 3, "running retile" );

                $self->retile_hosts();

                $self->debug( 3, "done with retile" );
            }

            if ( $self->config->{internal_previous_state} ne $state ) {
                $self->debug( 3, "resetting prev_state" );
                $self->config->{internal_previous_state} = $state;
            }
        }
    );

 #    $windows{main_window}->bind(
 #        '<Unmap>' => sub {
 #            $self->debug( 3, "Entering UNMAP" );
 #
 #            my $state = $windows{main_window}->state();
 #            $self->debug( 3,
 #                "state=$state previous=$config{internal_previous_state}" );
 #
 #            if ( $config{internal_previous_state} eq $state ) {
 #                $self->debug( 3, "repeating the same" );
 #            }
 #
 #            if ( $config{internal_previous_state} eq "mid-change" ) {
 #                $self->debug( 3, "dropping out as mid-change" );
 #                return;
 #            }
 #
 #            if ( $config{internal_previous_state} eq "normal" ) {
 #                $self->debug( 3, "withdrawing all windows" );
 #                foreach my $server ( reverse( keys(%servers) ) ) {
 #                    $xdisplay->req( 'UnmapWindow', $servers{$server}{wid} );
 #                    if ( $config{unmap_on_redraw} =~ /yes/i ) {
 #                        $xdisplay->req( 'UnmapWindow',
 #                            $servers{$server}{wid} );
 #                    }
 #                }
 #                $xdisplay->flush();
 #            }
 #
 #            if ( $config{internal_previous_state} ne $state ) {
 #                $self->debug( 3, "resetting prev_state" );
 #                $config{internal_previous_state} = $state;
 #            }
 #        }
 #    );

    return $self;
}

# for all key event, event hotkeys so there is only 1 key binding
sub key_event {
    my ($self)    = @_;
    my $event     = $Tk::event->T;
    my $keycode   = $Tk::event->k;
    my $keysymdec = $Tk::event->N;
    my $keysym    = $Tk::event->K;
    my $state = $Tk::event->s || 0;

    $menus{entrytext} = "";

    $self->debug( 3, "=========" );
    $self->debug( 3, "event    =$event" );
    $self->debug( 3, "keysym   =$keysym (state=$state)" );
    $self->debug( 3, "keysymdec=$keysymdec" );
    $self->debug( 3, "keycode  =$keycode" );
    $self->debug( 3, "state    =$state" );
    $self->debug( 3, "codetosym=$keycodetosym{$keysymdec}" )
        if ( $keycodetosym{$keysymdec} );
    $self->debug( 3, "symtocode=$keysymtocode{$keysym}" );
    $self->debug( 3, "keyboard =$keyboardmap{ $keysym }" )
        if ( $keyboardmap{$keysym} );

    #warn("debug stop point here");
    if ( $self->config->{use_hotkeys} eq "yes" ) {
        my $combo = $Tk::event->s . $Tk::event->K;

        $combo =~ s/Mod\d-//;

        $self->debug( 3, "combo=$combo" );

        foreach my $hotkey ( grep( /key_/, keys( %{ $self->config } ) ) ) {
            my $key = $self->config->{$hotkey};
            next if ( $key eq "null" );    # ignore disabled keys

            $self->debug( 3, "key=:$key:" );
            if ( $combo =~ /^$key$/ ) {
                $self->debug( 3, "matched combo" );
                if ( $event eq "KeyRelease" ) {
                    $self->debug( 2, "Received hotkey: $hotkey" );
                    $self->send_text_to_all_servers(
                        $self->config->{macro_servername} )
                        if ( $hotkey eq "key_clientname" );
                    $self->send_text_to_all_servers(
                        $self->config->{macro_hostname} )
                        if ( $hotkey eq "key_localname" );
                    $self->send_text_to_all_servers(
                        $self->config->{macro_username} )
                        if ( $hotkey eq "key_username" );
                    $self->add_host_by_name()
                        if ( $hotkey eq "key_addhost" );
                    $self->retile_hosts("force")
                        if ( $hotkey eq "key_retilehosts" );
                    $self->show_history() if ( $hotkey eq "key_history" );
                    $self->exit_prog()    if ( $hotkey eq "key_quit" );
                }
                return;
            }
        }
    }

    # look for a <Control>-d and no hosts, so quit
    $self->exit_prog()
        if ( $state =~ /Control/ && $keysym eq "d" and !%servers );

    $self->update_display_text( $keycodetosym{$keysymdec} )
        if ( $event eq "KeyPress" && $keycodetosym{$keysymdec} );

    # for all servers
    foreach ( keys(%servers) ) {

        # if active
        if ( $servers{$_}{active} == 1 ) {
            $self->debug( 3,
                "Sending event $event with code $keycode (state=$state) to window $servers{$_}{wid}"
            );

            $xdisplay->SendEvent(
                $servers{$_}{wid},
                0,
                $xdisplay->pack_event_mask($event),
                $xdisplay->pack_event(
                    'name'        => $event,
                    'detail'      => $keycode,
                    'state'       => $state,
                    'event'       => $servers{$_}{wid},
                    'root'        => $xdisplay->root(),
                    'same_screen' => 1,
                )
            ) || warn("Error returned from SendEvent: $!");
        }
    }
    $xdisplay->flush();

    return $self;
}

sub create_menubar() {
    my ($self) = @_;
    $self->debug( 2, "create_menubar: started" );
    $menus{bar} = $windows{main_window}->Menu();
    $windows{main_window}->configure( -menu => $menus{bar}, );

    $menus{file} = $menus{bar}->cascade(
        -label     => 'File',
        -menuitems => [
            [   "command",
                "Show History",
                -command => sub { $self->show_history; },
                -accelerator => $self->config->{key_history},
            ],
            [   "command",
                "Exit",
                -command => sub { $self->exit_prog },
                -accelerator => $self->config->{key_quit},
            ]
        ],
        -tearoff => 0,
    );

    my $host_menu_items = [
        [   "command",
            "Retile Windows",
            -command => sub { $self->retile_hosts },
            -accelerator => $self->config->{key_retilehosts},
        ],

#         [ "command", "Capture Terminal",    -command => sub { $self->capture_terminal), ],
        [   "command",
            "Set all active",
            -command => sub { $self->set_all_active() },
        ],
        [   "command",
            "Set half inactive",
            -command => sub { $self->set_half_inactive() },
        ],
        [   "command",
            "Toggle active state",
            -command => sub { $self->toggle_active_state() },
        ],
        [   "command",
            "Close inactive sessions",
            -command => sub { $self->close_inactive_sessions() },
        ],
        [   "command",
            "Add Host(s) or Cluster(s)",
            -command => sub { $self->add_host_by_name, },
            -accelerator => $self->config->{key_addhost},
        ],
        [   "command",
            "Re-add closed session(s)",
            -command => sub { $self->re_add_closed_sessions() },
        ],
        ''      # this is needed as build_host_menu always drops the
                # last item
    ];

    $menus{hosts} = $menus{bar}->cascade(
        -label     => 'Hosts',
        -tearoff   => 1,
        -menuitems => $host_menu_items
    );

    $host_menu_static_items = scalar( @{$host_menu_items} );

    $menus{send} = $menus{bar}->cascade(
        -label   => 'Send',
        -tearoff => 1,
    );

    $self->populate_send_menu();

    $menus{help} = $menus{bar}->cascade(
        -label     => 'Help',
        -menuitems => [
            [ 'command', "About", -command => sub { $windows{help}->Show } ],
            [   'command', "Documentation",
                -command => sub { $windows{manpage}->Show }
            ],
        ],
        -tearoff => 0,
    );

    $windows{main_window}->bind( '<KeyPress>' => [ $self => 'key_event' ], );
    $windows{main_window}
        ->bind( '<KeyRelease>' => [ $self => 'key_event' ], );
    $self->debug( 2, "create_menubar: completed" );
}

sub populate_send_menu_entries_from_xml {
    my ( $self, $menu, $menu_xml ) = @_;

    foreach my $menu_ref ( @{ $menu_xml->{menu} } ) {
        if ( $menu_ref->{menu} ) {
            $menus{ $menu_ref->{title} }
                = $menu->cascade( -label => $menu_ref->{title}, );
            $self->populate_send_menu_entries_from_xml(
                $menus{ $menu_ref->{title} }, $menu_ref, );
            if ( $menu_ref->{detach} && $menu_ref->{detach} =~ m/y/i ) {
                $menus{ $menu_ref->{title} }->menu->tearOffMenu()->raise;
            }
        }
        else {
            my $accelerator = undef;
            if ( $menu_ref->{accelerator} ) {
                $accelerator = $menu_ref->{accelerator};
            }
            if ( $menu_ref->{toggle} ) {
                $menus{send}->checkbutton(
                    -label       => 'Use Macros',
                    -variable    => \$self->config->{macros_enabled},
                    -offvalue    => 'no',
                    -onvalue     => 'yes',
                    -accelerator => $accelerator,
                );
            }
            else {
                my $command = undef;
                if ( $menu_ref->{command} ) {
                    $command = sub {
                        $self->send_text_to_all_servers(
                            $menu_ref->{command}[0] );
                    };
                }
                $menu->command(
                    -label       => $menu_ref->{title},
                    -command     => $command,
                    -accelerator => $accelerator,
                );
            }
        }
    }

    return $self;
}

sub populate_send_menu {
    my ($self) = @_;

    #    my @menu_items = ();
    if ( !-r $self->config->{send_menu_xml_file} ) {
        $self->debug( 2, 'Using default send menu' );

        $menus{send}->checkbutton(
            -label       => 'Use Macros',
            -variable    => \$self->config->{macros_enabled},
            -offvalue    => 'no',
            -onvalue     => 'yes',
            -accelerator => $self->config->{key_macros_enable},
        );

        $menus{send}->command(
            -label   => 'Remote Hostname',
            -command => sub {
                $self->send_text_to_all_servers(
                    $self->config->{macro_servername} );
            },
            -accelerator => $self->config->{key_clientname},
        );
        $menus{send}->command(
            -label   => 'Local Hostname',
            -command => sub {
                $self->send_text_to_all_servers(
                    $self->config->{macro_hostname} );
            },
            -accelerator => $self->config->{key_localname},
        );
        $menus{send}->command(
            -label   => 'Username',
            -command => sub {
                $self->send_text_to_all_servers(
                    $self->config->{macro_username} );
            },
            -accelerator => $self->config->{key_username},
        );
        $menus{send}->command(
            -label   => 'Test Text',
            -command => sub {
                $self->send_text_to_all_servers( 'echo ClusterSSH Version: '
                        . $self->config->{macro_version}
                        . $self->config->{macro_newline} );
            },
        );
        $menus{send}->command(
            -label   => 'Random Number',
            -command => sub {
                $self->send_variable_text_to_all_servers(
                    sub { int( rand(1024) ) } ),
                    ;
            },
        );
    }
    else {
        $self->debug(
            2,
            'Using xml send menu definition from ',
            $self->config->{send_menu_xml_file}
        );

        eval { require XML::Simple; };
        die 'Cannot load XML::Simple - has it been installed?  ', $@ if ($@);

        my $xml = XML::Simple->new( ForceArray => 1, );
        my $menu_xml = $xml->XMLin( $self->config->{send_menu_xml_file} );

        $self->debug( 3, 'xml send menu: ', $/, $xml->XMLout($menu_xml) );

        if ( $menu_xml->{detach} && $menu_xml->{detach} =~ m/y/i ) {
            $menus{send}->menu->tearOffMenu()->raise;
        }

        $self->populate_send_menu_entries_from_xml( $menus{send}, $menu_xml );
    }

    return $self;
}

sub run {
    my ($self) = @_;

    $self->getopts;

### main ###

    # only get xdisplay if we got past usage and help stuff
    $xdisplay = X11::Protocol->new();

    if ( !$xdisplay ) {
        die("Failed to get X connection\n");
    }

    $self->debug( 2, "VERSION: $VERSION" );

    # only use ssh_args from options if config file ssh_args not set AND
    # options is not the default value otherwise the default options
    # value is used instead of the config file
    if ( $self->config->{comms} eq 'ssh' ) {
        if ( $self->config->{ssh_args} ) {
            if (   $self->options->options
                && $self->options->options ne
                $self->options->options_default )
            {
                $self->config->{ssh_args} = $self->options->options;
            }
        }
        else {
            $self->config->{ssh_args} = $self->options->options
                if ( $self->options->options );
        }
    }

    $self->config->{terminal_args} = $self->options->term_args
        if ( $self->options->term_args );

    if ( $self->config->{terminal_args} =~ /-class (\w+)/ ) {
        $self->config->{terminal_allow_send_events}
            = "-xrm '$1.VT100.allowSendEvents:true'";
    }

    # if the user has asked for natural sorting we need to include an extra
    # module
    if ( $self->config()->{'use_natural_sort'} ) {
        eval { Module::Load::load('Sort::Naturally'); };
        if ($@) {
            warn(
                "natural sorting requested but unable to load Sort::Naturally: $@\n"
            );
        }
        else {
            $sort = sub { Sort::Naturally::nsort(@_) };
        }
    }

    $self->config->dump() if ( $self->options->dump_config );

    $self->evaluate_commands() if ( $self->options->evaluate );

    $self->get_font_size();

    $self->load_keyboard_map();

    # read in normal cluster files
    $self->config->{extra_cluster_file} .= ',' . $self->options->cluster_file
        if ( $self->options->cluster_file );
    $self->config->{extra_tag_file} .= ',' . $self->options->tag_file
        if ( $self->options->tag_file );

    $self->cluster->get_cluster_entries( split /,/,
        $self->config->{extra_cluster_file} || '' );
    $self->cluster->get_tag_entries( split /,/,
        $self->config->{extra_tag_file} || '' );

    if ( defined $self->options->list ) {
        my $eol = $self->options->quiet ? ' ' : $/;
        my $tab = $self->options->quiet ? ''  : "\t";
        if ( !$self->options->list ) {
            print( 'Available cluster tags:', $/ )
                unless ( $self->options->quiet );
            print $tab, $_, $eol
                foreach ( sort( $self->cluster->list_tags ) );

            my @external_clusters = $self->cluster->list_external_clusters;
            if (@external_clusters) {
                print( 'Available external command tags:', $/ )
                    unless ( $self->options->quiet );
                print $tab, $_, $eol foreach ( sort(@external_clusters) );
                print $/;
            }
        }
        else {
            print 'Tag resolved to hosts: ', $/
                unless ( $self->options->quiet );
            @servers = $self->resolve_names( $self->options->list );

            foreach my $svr (@servers) {
                print $tab, $svr, $eol;
            }
            print $/;
        }

        $self->debug(
            4,
            "Full clusters dump: ",
            $self->_dump_args_hash( $self->cluster->dump_tags )
        );
        $self->exit_prog();
    }

    if (@ARGV) {
        @servers = $self->resolve_names(@ARGV);
    }
    else {

        #if ( my @default = $self->cluster->get_tag('default') ) {
        if ( $self->cluster->get_tag('default') ) {
            @servers

                #    = $self->resolve_names( @default );
                = $self->resolve_names( $self->cluster->get_tag('default') );
        }
    }

    $self->create_windows();
    $self->create_menubar();

    $self->change_main_window_title();

    $self->debug( 2, "Capture map events" );
    $self->capture_map_events();

    $self->debug( 0, 'Opening to: ', join( ' ', @servers ) )
        if ( @servers && !$self->options->quiet );
    $self->open_client_windows(@servers);

    # Check here if we are tiling windows.  Here instead of in func so
    # can be tiled from console window if wanted
    if ( $self->config->{window_tiling} eq "yes" ) {
        $self->retile_hosts();
    }
    else {
        $self->show_console();
    }

    $self->build_hosts_menu();

    $self->debug( 2, "Sleeping for a mo" );
    select( undef, undef, undef, 0.5 );

    $self->debug( 2, "Sorting focus on console" );
    $windows{text_entry}->focus();

    $self->debug( 2, "Marking main window as user positioned" );
    $windows{main_window}->positionfrom('user')
        ;    # user puts it somewhere, leave it there

    $self->debug( 2, "Setting up repeat" );
    $self->setup_repeat();

    # Start event loop
    $self->debug( 2, "Starting MainLoop" );
    MainLoop();

    # make sure we leave program in an expected way
    $self->exit_prog();
}

1;

__END__

=pod

=head1 NAME

App::ClusterSSH - A container for functions of the ClusterSSH programs

=head1 SYNOPSIS

There is nothing in this module for public consumption.  See documentation
for F<cssh>, F<crsh>, F<ctel>, F<ccon>, or F<cscp> instead.

=head1 DESCRIPTION

This is the core for App::ClusterSSH.  You should probably look at L<cssh> 
instead.

=head1 SUBROUTINES/METHODS

These methods are listed here to tidy up Pod::Coverage test reports but
will most likely be moved into other modules.  There are some notes within 
the code until this time.

=over 2

=item REAPER

=item add_host_by_name

=item add_option

=item build_hosts_menu

=item capture_map_events

=item capture_terminal

=item change_main_window_title

=item close_inactive_sessions

=item config

=item helper

=item cluster

=item create_menubar

=item create_windows

=item dump_config

=item getopts

=item list_tags

=item evaluate_commands

=item exit_prog

=item get_clusters

=item get_font_size

=item get_keycode_state

=item key_event

=item load_config_defaults

=item load_configfile

=item load_keyboard_map

=item new

=item open_client_windows

=item options

=item parse_config_file

=item pick_color

=item populate_send_menu

=item populate_send_menu_entries_from_xml

=item re_add_closed_sessions

=item remove_repeated_servers

=item resolve_names

=item slash_slash_equal

An implementation of the //= operator that works on older Perls.
slash_slash_equal($a, 0) is equivalent to $a //= 0

=item retile_hosts

=item run

=item send_resizemove

=item send_text

=item send_text_to_all_servers

=item set_all_active

=item set_half_inactive

=item setup_repeat

=item send_variable_text_to_all_servers

=item show_console

=item show_history

=item substitute_macros

=item terminate_host

=item toggle_active_state

=item update_display_text

=item write_default_user_config
                                           
=back

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-clusterssh at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-ClusterSSH>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::ClusterSSH

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-ClusterSSH>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-ClusterSSH>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-ClusterSSH>

=item * Search CPAN

L<http://search.cpan.org/dist/App-ClusterSSH/>

=back

=head1 ACKNOWLEDGEMENTS

Please see the THANKS file from the original distribution.

=head1 AUTHOR

Duncan Ferguson, C<< <duncan_j_ferguson at yahoo.co.uk> >>

=head1 COPYRIGHT & LICENSE

Copyright 1999-2015 Duncan Ferguson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
