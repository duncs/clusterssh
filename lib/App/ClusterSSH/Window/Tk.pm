use strict;
use warnings;

package App::ClusterSSH::Window::Tk;

# ABSTRACT: Object for creating windows using Tk

use English qw( -no_match_vars );

use base qw/ App::ClusterSSH::Base /;
use vars qw/ %keysymtocode %keycodetosym /;

use Sys::Hostname qw/ hostname /;
use File::Temp qw/:POSIX/;
use Fcntl;
use POSIX ":sys_wait_h";
use POSIX qw/:sys_wait_h strftime mkfifo/;
use Tk 800.022;
use Tk::Xlib;
use Tk::ROText;
require Tk::Dialog;
require Tk::LabEntry;
use Symbol qw/ gensym /;
use IPC::Open3;
use X11::Protocol 0.56;
use X11::Protocol::Constants qw/ Shift Mod5 ShiftMask /;
use X11::Protocol::WM 29;
use X11::Keysyms '%keysymtocode', 'MISCELLANY', 'XKB_KEYS', '3270', 'LATIN1',
    'LATIN2', 'LATIN3', 'LATIN4', 'KATAKANA', 'ARABIC', 'CYRILLIC', 'GREEK',
    'TECHNICAL', 'SPECIAL', 'PUBLISHING', 'APL', 'HEBREW', 'THAI', 'KOREAN';

# Module to contain all Tk specific functionality

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

$keysymtocode{unknown_sym} = 0xFFFFFF;    # put in a default "unknown" entry
$keysymtocode{EuroSign}
    = 0x20AC;    # Euro sign - missing from X11::Protocol::Keysyms

# and also map it the other way
%keycodetosym = reverse %keysymtocode;

sub initialise {
    my ($self) = @_;

    # only get xdisplay if we got past usage and help stuff
    $xdisplay = X11::Protocol->new();

    if ( !$xdisplay ) {
        die("Failed to get X connection\n");
    }

    return $self;
}

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

sub terminate_all_hosts {
    my ($self) = @_;

    # for each of the client windows, send a kill.
    #     # to make sure we catch all children, even when they haven't
    #         # finished starting or received the kill signal, do it like this
    while (%servers) {
        foreach my $svr ( keys(%servers) ) {
            $self->terminate_host($svr);
        }
    }

    return $self;
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
                "'" . $self->parent->helper->script( $self->config ) . "'",
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

    return if !%servers;

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
            = $self->parent->resolve_names( split( /\s+/, $menus{host_entry} ) );
        $self->debug( 0, 'Opening to: ', join( ' ', @names ) ) if (@names);
        $self->open_client_windows(@names);
    }

    if ( defined $menus{listbox} && $menus{listbox}->curselection() ) {
        my @hosts = $menus{listbox}->get( $menus{listbox}->curselection() );
        $self->debug( 2, "host=", join( ' ', @hosts ) );
        $self->open_client_windows( $self->parent->resolve_names(@hosts) );
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
        $ENV{CSSH_SERVERNAME} = $servername;
    }
    {
        my $macro_hostname = $self->config->{macro_hostname};
        my $hostname       = $self->config->{hostname_override} || hostname();
        $text =~ s!$macro_hostname!$hostname!xsmg;
        $ENV{CSSH_HOSTNAME} = $hostname;
    }
    {
        my $macro_username = $self->config->{macro_username};
        my $username       = $servers{$svr}{username};
        $username ||= getpwuid($UID);
        $text =~ s!$macro_username!$username!xsmg;
        $ENV{CSSH_USERNAME} = $username;
    }
    {
        my $macro_newline = $self->config->{macro_newline};
        $text =~ s!$macro_newline!\n!xsmg;
    }
    {
        my $macro_version = $self->config->{macro_version};
        my $version       = $self->parent->VERSION;
        $text =~ s/$macro_version/$version/xsmg;
        $ENV{CSSH_VERSION} = $version;
    }

    $ENV{CSSH_CONNECTION_STRING} = $servers{$svr}{connect_string};
    $ENV{CSSH_CONNECTION_PORT}   = $servers{$svr}{port};

    # Set up environment variables in the macro environment
    for my $i (qw/ 1 2 3 4 / ) {
        my $macro_user_command = 'macro_user_'.$i.'_command';
        my $macro_user = $self->config->{'macro_user_'.$i};

        next unless $text =~ $macro_user;
        if( ! $self->config->{ $macro_user_command } ) {
            $text =~ s/$macro_user//xsmg;
            next;
        }

        my $cmd = $self->config->{ $macro_user_command };

        local $SIG{CHLD} = undef;

        my $stderr_fh = gensym;
        my $stdout_fh = gensym;
        my $child_pid = eval { open3(undef, $stdout_fh, $stderr_fh, $cmd) };

        if (my $err=$@) {
            # error message is hardcoded into open3 - tidy it up a little for our users
            $err=~ s/ at .*//;
            $err=~ s/open3: //;
            $err =~ s/( failed)/' $1/;
            $err =~ s/(exec of) /$1 '/;
            warn "Macro failure for '$macro_user_command': $err";
            next;
        }
        waitpid($child_pid, 0);
        my $cmd_rc = $? >> 8;

        my @stdout = <$stdout_fh>;
        my @stderr = <$stderr_fh>;

        if ( $cmd_rc > 0 || @stderr ){
            warn "Macro failure for '$macro_user_command'",$/;
            warn "Exited with error output:: @stderr" if @stderr;
            warn "Exited with non-zero return code: $cmd_rc", $/ if $cmd_rc;
        } else {
            #$self->send_text_to_all_servers( $stdout );
            return join('', @stdout);
        }
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
    $windows{main_window}->withdraw
        if $windows{main_window}->state ne "withdrawn";

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
    if ( $self->config->{rows} != -1 || $self->config->{cols} != -1 ) {
        if ( $self->config->{rows} != -1 ) {
            $self->config->{internal_rows}    = $self->config->{rows};
            $self->config->{internal_columns} = int(
                (         $self->config->{internal_total}
                        / $self->config->{internal_rows}
                ) + 0.999
            );
        }
        else {
            $self->config->{internal_columns} = $self->config->{cols};
            $self->config->{internal_rows}    = int(
                (         $self->config->{internal_total}
                        / $self->config->{internal_columns}
                ) + 0.999
            );
        }
    }
    else {
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
    }
    $self->debug( 2, "Screen Columns: ", $self->config->{internal_columns} );
    $self->debug( 2, "Screen Rows: ",    $self->config->{internal_rows} );
    $self->debug( 2, "Fill scree: ",     $self->config->{fillscreen} );

    # Now adjust the height of the terminal to either the max given,
    # or to get everything on screen
    if ( $self->config->{fillscreen} ne 'yes' ) {
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
        $self->config->{internal_terminal_height} = (
              $height > $self->config->{internal_terminal_height}
            ? $self->config->{internal_terminal_height}
            : $height
        );
    }
    else {
        $self->config->{internal_terminal_height} = int(
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
        $self->config->{internal_terminal_width} = int(
            (   (         $self->config->{internal_screen_width}
                        - $self->config->{screen_reserve_left}
                        - $self->config->{screen_reserve_right}
                ) - (
                    $self->config->{internal_columns} * (
                              $self->config->{terminal_reserve_left}
                            + $self->config->{terminal_reserve_right}
                    )
                )
            ) / $self->config->{internal_columns}
        );
    }
    $self->debug( 2, "Terminal h: ",
        $self->config->{internal_terminal_height},
        ", w: ", $self->config->{internal_terminal_width} );

    $self->config->dump("noexit") if ( $self->options->debug_level > 1 );

    # now find the size of the window decorations
    if ( !exists( $self->config->{internal_terminal_wm_decoration_left} ) ) {

   # Debian #842965 (https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=842965)
   # disable behavior added in https://github.com/duncs/clusterssh/pull/66
   # unless explicitly enabled with auto_wm_decoration_offsets => yes

        if ( $self->config->{auto_wm_decoration_offsets} =~ /yes/i ) {

            # use the first window as exemplary
            my ($wid) = $servers{ ( keys(%servers) )[0] }{wid};

            if ( defined($wid) ) {

                # get the WM decoration sizes
                (   $self->config->{internal_terminal_wm_decoration_left},
                    $self->config->{internal_terminal_wm_decoration_right},
                    $self->config->{internal_terminal_wm_decoration_top},
                    $self->config->{internal_terminal_wm_decoration_bottom}
                    )
                    = X11::Protocol::WM::get_net_frame_extents( $xdisplay,
                    $wid );
            }
        }

        # in case the WM call failed we set some defaults
        for my $v (
            qw/ internal_terminal_wm_decoration_left internal_terminal_wm_decoration_right internal_terminal_wm_decoration_top internal_terminal_wm_decoration_bottom /
            )
        {
            $self->config->{$v} = 0 if ( !defined $self->config->{$v} );
        }
    }

    # now we have the info, plot first window position
    my @hosts;
    my ( $current_x, $current_y, $current_row, $current_col ) = 0;
    if ( $self->config->{window_tiling_direction} =~ /right/i ) {
        $self->debug( 2, "Tiling top left going bot right" );
        @hosts     = $self->sort->( keys(%servers) );
        $current_x = $self->config->{screen_reserve_left}
            + $self->config->{terminal_reserve_left};
        $current_y = $self->config->{screen_reserve_top}
            + $self->config->{terminal_reserve_top};
        $current_row = 0;
        $current_col = 0;
    }
    else {
        $self->debug( 2, "Tiling bot right going top left" );
        @hosts = reverse( $self->sort->( keys(%servers) ) );
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

sub build_hosts_menu() {
    my ($self) = @_;

    return if ( $self->config->{hide_menu} );

    $self->debug( 2, "Building hosts menu" );

    # first, empty the hosts menu from the last static entry + 1 on
    my $menu = $menus{bar}->entrycget( 'Hosts', -menu );
    $menu->delete( $host_menu_static_items, 'end' );

    $self->debug( 3, "Menu deleted" );

    # add back the separator
    $menus{hosts}->separator;

    $self->debug( 3, "Parsing list" );

    my $menu_item_counter = $host_menu_static_items;
    foreach my $svr ( $self->sort->( keys(%servers) ) ) {
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

            # See if there are any commands in the external command pipe
            if ( defined $self->{external_command_pipe_fh} ) {
                my $ext_cmd;
                sysread( $self->{external_command_pipe_fh}, $ext_cmd, 400 );
                if ($ext_cmd) {
                    my @external_commands = split( /\n/, $ext_cmd );
                    for my $cmd_line (@external_commands) {
                        chomp($cmd_line);
                        my ( $cmd, @tags ) = split /\s+/, $cmd_line;
                        $self->debug( 2,
                            "Got external command: $cmd -> @tags" );

                        for ($cmd) {
                            if (m/^open$/) {
                                my @new_hosts = $self->parent->resolve_names(@tags);
                                $self->open_client_windows(@new_hosts);
                                $self->build_hosts_menu();
                                last;
                            }
                            if (m/^retile$/) {
                                $self->retile_hosts();
                                last;
                            }
                            warn "Unknown external command: $cmd_line", $/;
                        }
                    }
                }
            }

#$self->debug( 3, "Number of servers in hash is: ", scalar( keys(%servers) ) );

            foreach my $svr ( keys(%servers) ) {
                if ( defined( $servers{$svr}{pid} ) ) {
                    if ( !kill( 0, $servers{$svr}{pid} ) ) {
                        $build_menu = 1;
                        push( @dead_hosts, $servers{$svr}{connect_string} );
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
                    $self->parent->exit_prog;
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
    my ($screen_height) = $xdisplay->{height_in_pixels};
    my ($screen_width) = $xdisplay->{width_in_pixels};
    $self->debug( 2, "create_windows: started" );

    $windows{main_window}
        = MainWindow->new( -title => "ClusterSSH", -class => 'cssh', );
    if ($screen_height * $screen_width >= 8294400) # display 4k or bigger
    {
        $windows{main_window}->optionAdd('*font', 'Nimbus 14'); # better for 4k displays
    }
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

    $windows{main_window}
        ->bind( '<Destroy>' => sub { $self->parent->exit_prog } );

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

    $windows{help} = $windows{main_window}->DialogBox(
        -popover    => $windows{main_window},
        -overanchor => "c",
        -popanchor  => "c",
        -class      => 'cssh',
        -title      => 'About Cssh',
    );

    my @helptext = (
        "Title:   Cluster Administrator Console using SSH",
        "Version: " . $App::ClusterSSH::VERSION,
        "Project: https://github.com/duncs/clusterssh",
        "Issues:  https://github.com/duncs/clusterssh/issues",
    );

    $windows{helptext} = $windows{help}->Text(
        -height => scalar(@helptext),
        -width  => 62,
    )->pack( -fill => 'both' );
    $windows{helptext}->insert( 'end', join( $/, @helptext ) );
    $windows{helptext}->configure( -state => 'disabled' );

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

    my @tags = $self->{parent}->cluster->list_tags();
    my @external_tags
        = map {"$_ *"} $self->parent->cluster->list_external_clusters();
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
                    $self->send_text_to_all_servers(
                        $self->config->{macro_user_1} )
                        if ( $hotkey eq "key_user_1" );
                    $self->send_text_to_all_servers(
                        $self->config->{macro_user_2} )
                        if ( $hotkey eq "key_user_2" );
                    $self->send_text_to_all_servers(
                        $self->config->{macro_user_3} )
                        if ( $hotkey eq "key_user_3" );
                    $self->send_text_to_all_servers(
                        $self->config->{macro_user_4} )
                        if ( $hotkey eq "key_user_4" );
                    $self->add_host_by_name()
                        if ( $hotkey eq "key_addhost" );
                    $self->retile_hosts("force")
                        if ( $hotkey eq "key_retilehosts" );
                    $self->show_history() if ( $hotkey eq "key_history" );
                    $self->parent->exit_prog() if ( $hotkey eq "key_quit" );
                }
                return;
            }
        }
    }

    # look for a <Control>-d and no hosts, so quit
    $self->parent->exit_prog()
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

    $windows{main_window}->configure( -menu => $menus{bar}, )
        unless $self->config->{hide_menu};

    $menus{file} = $menus{bar}->cascade(
        -label     => 'File',
        -menuitems => [
            [   "command",
                "Show History",
                -command     => sub { $self->show_history; },
                -accelerator => $self->config->{key_history},
            ],
            [   "checkbutton",
                "Auto Quit",
                -variable => \$self->config->{auto_quit},
                -offvalue => 'no',
                -onvalue  => 'yes',
            ],

           # While this autoclose menu works as expected, the functionality
           # within terminals does not.  "auto_close" is set when the terminal
           # is opened and is not updated when the variable is changed.
           #
           #    [   "cascade" => "Auto Close",
           #        -menuitems => [
           #            [   "radiobutton",
           #                "Auto Close",
           #                -variable    => \$self->config->{auto_close},
           #                -label    => 'Off',
           #                -value    => '0',
           #            ],
           #            [   "radiobutton",
           #                "Auto Close",
           #                -variable    => \$self->config->{auto_close},
           #                -label    => '5 Seconds',
           #                -value    => '5',
           #            ],
           #            [   "radiobutton",
           #                "Auto Close",
           #                -variable    => \$self->config->{auto_close},
           #                -label    => '10 Seconds',
           #                -value    => '10',
           #            ],
           #        ],
           #    -tearoff => 0,
           #    ],
            [   "command",
                "Exit",
                -command     => sub { $self->parent->exit_prog },
                -accelerator => $self->config->{key_quit},
            ]
        ],
        -tearoff => 0,
    );

    my $host_menu_items = [
        [   "command",
            "Retile Windows",
            -command     => sub { $self->retile_hosts },
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
            -command     => sub { $self->add_host_by_name, },
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

        my $xml      = XML::Simple->new( ForceArray => 1, );
        my $menu_xml = $xml->XMLin( $self->config->{send_menu_xml_file} );

        $self->debug( 3, 'xml send menu: ', $/, $xml->XMLout($menu_xml) );

        if ( $menu_xml->{detach} && $menu_xml->{detach} =~ m/y/i ) {
            $menus{send}->menu->tearOffMenu()->raise;
        }

        $self->populate_send_menu_entries_from_xml( $menus{send}, $menu_xml );
    }

    return $self;
}

sub console_focus {
    my ($self) = @_;

    $self->debug( 2, "Sorting focus on console" );
    $windows{text_entry}->focus();

    $self->debug( 2, "Marking main window as user positioned" );

    # user puts it somewhere, leave it there
    $windows{main_window}->positionfrom('user');

    return $self;
}

sub mainloop {
    my ($self) = @_;

    $self->debug( 2, "Starting MainLoop" );
    MainLoop();
    return $self;
}

1;

=pod

=head1 NAME

App::ClusterSSH::Window::TK - Base Tk windows object

=head1 DESCRIPTION

Base object for using Tk - must be pulled into App::ClusterSSH::Window for use

=head1 METHODS

=over 4

=item add_host_by_name

=item build_hosts_menu

=item capture_map_events

=item change_main_window_title

=item close_inactive_sessions

=item console_focus

=item create_menubar

=item create_windows

=item get_font_size

=item get_keycode_state

=item initialise

=item key_event

=item load_keyboard_map

=item mainloop

=item open_client_windows

=item pick_color

=item populate_send_menu

=item populate_send_menu_entries_from_xml

=item re_add_closed_sessions

=item retile_hosts

=item send_resizemove

=item send_text

=item send_text_to_all_servers

=item send_variable_text_to_all_servers

=item set_all_active

=item set_half_inactive

=item setup_repeat

=item show_console

=item show_history

=item substitute_macros

=item terminate_all_hosts

=item terminate_host

=item toggle_active_state

=item update_display_text

=back
