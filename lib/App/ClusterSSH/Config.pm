use strict;
use warnings;

package App::ClusterSSH::Config;

# ABSTRACT: ClusterSSH::Config - Object representing application configuration

=head1 SYNOPSIS

=head1 DESCRIPTION

Object representing application configuration

=cut

use Carp;
use Try::Tiny;

use FindBin qw($Script);
use File::Copy;

use base qw/ App::ClusterSSH::Base /;
use App::ClusterSSH::Cluster;

my $clusters;
my %old_clusters;
my @app_specific = (qw/ command title comms method parent /);

# list of config items to not write out when writing the default config
my @ignore_default_config = (qw/ user /);

my %default_config = (
    terminal                   => "xterm",
    terminal_args              => "",
    terminal_title_opt         => "-T",
    terminal_colorize          => 1,
    terminal_bg_style          => 'dark',
    terminal_allow_send_events => "-xrm '*.VT100.allowSendEvents:true'",
    terminal_font              => "6x13",
    terminal_size              => "80x24",

    use_hotkeys             => "yes",
    key_quit                => "Alt-q",
    key_addhost             => "Control-Shift-plus",
    key_clientname          => "Alt-n",
    key_history             => "Alt-h",
    key_localname           => "Alt-l",
    key_retilehosts         => "Alt-r",
    key_macros_enable       => "Alt-p",
    key_paste               => "Control-v",
    key_username            => "Alt-u",
    key_user_1              => "Alt-1",
    key_user_2              => "Alt-2",
    key_user_3              => "Alt-3",
    key_user_4              => "Alt-4",
    mouse_paste             => "Button-2",
    auto_quit               => "yes",
    auto_close              => 5,
    use_natural_sort        => 0,
    window_tiling           => "yes",
    window_tiling_direction => "right",
    console_position        => "",

    screen_reserve_top    => 0,
    screen_reserve_bottom => 60,
    screen_reserve_left   => 0,
    screen_reserve_right  => 0,

    terminal_reserve_top    => 5,
    terminal_reserve_bottom => 0,
    terminal_reserve_left   => 5,
    terminal_reserve_right  => 0,

    terminal_decoration_height => 10,
    terminal_decoration_width  => 8,

    console      => 'console',
    console_args => '',
    rsh          => 'rsh',
    rsh_args     => "",
    telnet       => 'telnet',
    telnet_args  => "",
    ssh          => 'ssh',
    ssh_args     => "",
    sftp         => 'sftp',
    sftp_args    => "",

    extra_tag_file           => '',
    extra_cluster_file       => '',
    external_cluster_command => '',
    external_command_mode    => '0600',
    external_command_pipe    => '',

    unmap_on_redraw => "no",    # Debian #329440

    show_history   => 0,
    history_width  => 40,
    history_height => 10,

    command             => q{},
    command_pre         => q{},
    command_post        => q{},
    hide_menu           => 0,
    max_host_menu_items => 30,

    macros_enabled   => 'yes',
    macro_servername => '%s',
    macro_hostname   => '%h',
    macro_username   => '%u',
    macro_newline    => '%n',
    macro_version    => '%v',
    macro_user_1     => '%1',
    macro_user_2     => '%2',
    macro_user_3     => '%3',
    macro_user_4     => '%4',

    macro_user_1_command     => '',
    macro_user_2_command     => '',
    macro_user_3_command     => '',
    macro_user_4_command     => '',

    max_addhost_menu_cluster_items => 6,
    menu_send_autotearoff          => 0,
    menu_host_autotearoff          => 0,

    unique_servers    => 0,
    use_all_a_records => 0,

    send_menu_xml_file => $ENV{HOME} . '/.clusterssh/send_menu',

    auto_wm_decoration_offsets => "no",    # Debian #842965

    # don't set username here as takes precendence over ssh config
    user => '',
    rows => -1,
    cols => -1,

    fillscreen => "no",

);

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%default_config);

    ( my $comms = $Script ) =~ s/^c//;

    $comms = 'telnet'  if ( $comms eq 'tel' );
    $comms = 'console' if ( $comms eq 'con' );
    $comms = 'ssh'     if ( $comms eq 'lusterssh' );
    $comms = 'sftp'    if ( $comms eq 'sftp' );

    # list of allowed comms methods
    if ( 'ssh rsh telnet sftp console' !~ m/\b$comms\b/ ) {
        $self->{comms} = 'ssh';
    }
    else {
        $self->{comms} = $comms;
    }

    $self->{title} = uc($Script);

    $clusters = App::ClusterSSH::Cluster->new();

    return $self->validate_args(%args);
}

sub validate_args {
    my ( $self, %args ) = @_;

    my @unknown_config = ();

    foreach my $config ( sort( keys(%args) ) ) {
        if ( grep /$config/, @app_specific ) {

            #     $self->{$config} ||= 'unknown';
            next;
        }

        if ( exists $self->{$config} ) {
            $self->{$config} = $args{$config};
        }
        else {
            push( @unknown_config, $config );
        }
    }

    if (@unknown_config) {
        croak(
            App::ClusterSSH::Exception::Config->throw(
                unknown_config => \@unknown_config,
                error          => $self->loc(
                    'Unknown configuration parameters: [_1]' . $/,
                    join( ',', @unknown_config )
                )
            )
        );
    }

    if ( !$self->{comms} ) {
        croak(
            App::ClusterSSH::Exception::Config->throw(
                error => $self->loc( 'Invalid variable: comms' . $/ ),
            ),
        );
    }

    if ( !$self->{ $self->{comms} } ) {
        croak(
            App::ClusterSSH::Exception::Config->throw(
                error => $self->loc(
                    'Invalid variable: [_1]' . $/,
                    $self->{comms}
                ),
            ),
        );
    }

    # check the terminal has been found correctly
    # looking for the terminal should not be fatal
    if ( !-e $self->{terminal} ) {
        eval { $self->{terminal} = $self->find_binary( $self->{terminal} ); };
        if ($@) {
            warn $@->message;
        }
    }

    return $self;
}

sub parse_config_file {
    my ( $self, $config_file ) = @_;

    $self->debug( 2, 'Loading in config file: ', $config_file );

    #    if ( !-e $config_file || !-r $config_file ) {
    #        croak(
    #            App::ClusterSSH::Exception::Config->throw(
    #                error => $self->loc(
    #                    'File [_1] does not exist or cannot be read' . $/,
    #                    $config_file
    #                ),
    #            ),
    #        );
    #    }
    #
    #    open( CFG, $config_file ) or die("Couldnt open $config_file: $!");
    #    my $l;
    #    my %read_config;
    #    while ( defined( $l = <CFG> ) ) {
    #        next
    #            if ( $l =~ /^\s*$/ || $l =~ /^#/ )
    #            ;    # ignore blank lines & commented lines
    #        $l =~ s/#.*//;     # remove comments from remaining lines
    #        $l =~ s/\s*$//;    # remove trailing whitespace
    #
    #        # look for continuation lines
    #        chomp $l;
    #        if ( $l =~ s/\\\s*$// ) {
    #            $l .= <CFG>;
    #            redo unless eof(CFG);
    #        }
    #
    #        next unless $l =~ m/\s*(\S+)\s*=\s*(.*)\s*/;
    #        my ( $key, $value ) = ( $1, $2 );
    #        if ( defined $key && defined $value ) {
    #            $read_config{$key} = $value;
    #            $self->debug( 3, "$key=$value" );
    #        }
    #    }
    #    close(CFG);

    my %read_config;
    %read_config
        = $self->load_file( type => 'config', filename => $config_file );

    # grab any clusters from the config before validating it
    if ( $read_config{clusters} ) {
        $self->debug( 3, "Picked up clusters defined in $config_file" );
        foreach my $cluster ( sort split / /, $read_config{clusters} ) {
            if ( $read_config{$cluster} ) {
                $clusters->register_tag( $cluster,
                    split( / /, $read_config{$cluster} ) );
                $old_clusters{$cluster} = $read_config{$cluster};
                delete( $read_config{$cluster} );
            }
        }
        delete( $read_config{clusters} );
    }

    # tidy up entries, just in case
    $read_config{terminal_font} =~ s/['"]//g
        if ( $read_config{terminal_font} );

    $self->validate_args(%read_config);

    # Look at the user macros and if not set remove the hotkey for them
    for my $i (qw/ 1 2 3 4 /) {
        if ( ! $self->{"macro_user_${i}_command"} ) {
            delete $self->{"key_user_${i}"};
        }
    }

    return $self;
}

sub load_configs {
    my ( $self, @configs ) = @_;

    for my $config (
        '/etc/csshrc',
        $ENV{HOME} . '/.csshrc',
        $ENV{HOME} . '/.clusterssh/config',
        )
    {
        $self->parse_config_file($config) if ( -e $config && ! -d _ );
    }

    # write out default config file if necesasry
    try {
        $self->write_user_config_file();
    }
    catch {
        warn $_, $/;
    };

    # Attempt to load in provided config files.  Also look for anything
    # relative to config directory
    for my $config (@configs) {
        next unless ($config);    # can be null when passed from Getopt::Long
        $self->parse_config_file($config) if ( -e $config && ! -d _ );

        my $file = $ENV{HOME} . '/.clusterssh/config_' . $config;
        $self->parse_config_file($file) if ( -e $file && ! -d _ );
    }

    return $self;
}

sub write_user_config_file {
    my ($self) = @_;

    # attempt to move the old config file to one side
    if ( -f "$ENV{HOME}/.csshrc" ) {
        eval { move( "$ENV{HOME}/.csshrc", "$ENV{HOME}/.csshrc.DISABLED" ) };

        if ($@) {
            croak(
                App::ClusterSSH::Exception::Config->throw(
                    error => $self->loc(
                        'Unable to move [_1] to [_2]: [_3]' . $/,
                        '$HOME/.csshrc', '$HOME/.csshrc.DISABLED', $@
                    ),
                )
            );
        }
        else {
            warn(
                $self->loc(
                    'Moved [_1] to [_2]' . $/, '$HOME/.csshrc',
                    '$HOME/.csshrc.DISABLED'
                ),
            );
        }
    }

    return if ( -f "$ENV{HOME}/.clusterssh/config" );

    if ( !-d "$ENV{HOME}/.clusterssh" ) {
        if ( !mkdir("$ENV{HOME}/.clusterssh") ) {
            croak(
                App::ClusterSSH::Exception::Config->throw(
                    error => $self->loc(
                        'Unable to create directory [_1]: [_2]' . $/,
                        '$HOME/.clusterssh', $!
                    ),
                ),
            );

        }
    }

    # Debian #673507 - migrate clusters prior to writing ~/.clusterssh/config
    # in order to update the extra_cluster_file property
    if (%old_clusters) {
        if ( open( my $fh, ">", "$ENV{HOME}/.clusterssh/clusters" ) ) {
            print $fh '# '
                . $self->loc('Tag definitions moved from old .csshrc file'),
                $/;
            foreach ( sort( keys(%old_clusters) ) ) {
                print $fh $_, ' ', join( ' ', $old_clusters{$_} ), $/;
            }
            close($fh);
        }
        else {
            croak(
                App::ClusterSSH::Exception::Config->throw(
                    error => $self->loc(
                        'Unable to write [_1]: [_2]' . $/,
                        '$HOME/.clusterssh/clusters',
                        $!
                    ),
                ),
            );
        }
    }

    if ( open( CONFIG, ">", "$ENV{HOME}/.clusterssh/config" ) ) {
        foreach ( sort( keys(%$self) ) ) {
            my $comment = '';
            if ( grep /$_/, @ignore_default_config ) {
                $comment = '#';
            }
            print CONFIG ${comment}, $_, '=', $self->{$_}, $/;
        }
        close(CONFIG);
        warn(
            $self->loc(
                'Created new configuration file within [_1]' . $/,
                '$HOME/.clusterssh/'
            )
        );
    }
    else {
        croak(
            App::ClusterSSH::Exception::Config->throw(
                error => $self->loc(
                    'Unable to write default [_1]: [_2]' . $/,
                    '$HOME/.clusterssh/config', $!
                ),
            ),
        );
    }

    return $self;
}

# search given directories for the given file
sub search_dirs {
    my ( $self, $file, @directories ) = @_;

    my $path;

    foreach my $dir (@directories) {
        $self->debug( 3, "Looking for $file in $dir" );

        if ( -f $dir . '/' . $file && -x $dir . '/' . $file ) {
            $path = $dir . '/' . $file;
            $self->debug( 2, "Found at $path" );
            last;
        }
    }

    return $path;
}

# could use File::Which for some of this but we also search a few other places
# just in case $PATH isnt set up right
sub find_binary {
    my ( $self, $binary ) = @_;

    if ( !$binary ) {
        croak(
            App::ClusterSSH::Exception::Config->throw(
                error => $self->loc('argument not provided') . $/,
            ),
        );
    }

    $self->debug( 2, "Looking for $binary" );

    # if not found, strip the path and look again
    if ( $binary =~ m!^/! ) {
        if ( -f $binary ) {
            $self->debug( 2, "Already have full path to in $binary" );
            return $binary;
        }
        else {
            $self->debug( 2, "Full path for $binary incorrect; searching" );
            $binary =~ s!^.*/!!;
        }
    }

    my $path;
    if ( !-x $binary || substr( $binary, 0, 1 ) ne '/' ) {
        $path = $self->search_dirs( $binary, split( /:/, $ENV{PATH} ) );

        # if it is on $PATH then no need to qualitfy the path to it
        # keep it as it is
        if ($path) {
            return $binary;
        }
        else {
            $path = $self->search_dirs(
                $binary, qw!
                    /bin
                    /sbin
                    /usr/sbin
                    /usr/bin
                    /usr/local/bin
                    /usr/local/sbin
                    /opt/local/bin
                    /opt/local/sbin
                    !
            );
        }

    }
    else {
        $self->debug( 2, "Already configured OK" );
        $path = $binary;
    }
    if ( !$path || !-f $path || !-x $path ) {
        croak(
            App::ClusterSSH::Exception::Config->throw(
                error => $self->loc(
                    '"[_1]" binary not found - please amend $PATH or the cssh config file'
                        . $/,
                    $binary
                ),
            ),
        );
    }

    chomp($path);
    return $path;
}

sub dump {
    my ( $self, $no_exit, ) = @_;

    $self->debug( 3, 'Dumping config to STDOUT' );
    print( '# Configuration dump produced by "cssh -d"', $/ );

    foreach my $key ( sort keys %$self ) {
        my $comment = '';
        if ( grep /$key/, @app_specific ) {
            next;
        }
        if ( grep /$key/, @ignore_default_config ) {
            $comment = '#';
        }
        print $comment, $key, '=', $self->{$key}, $/;
    }

    $self->exit if ( !$no_exit );
}

#use overload (
#    q{""} => sub {
#        my ($self) = @_;
#        return $self->{hostname};
#    },
#    fallback => 1,
#);

1;

=head1 METHODS

=over 4

=item $host=ClusterSSH::Config->new ({ })

Create a new configuration object.

=item $config->parse_config_file('<filename>');

Read in configuration from given filename

=item $config->validate_args();

Validate and apply all configuration loaded at this point

=item $path = $config->search_dirs('<name>', @seaarch_directories);

Search the given directories for the name given.  Return undef if not found.

=item $path = $config->find_binary('<name>');

Locate the binary <name> and return the full path.  Doesn't just search 
$PATH in case the environment isn't set up correctly

=item $config->load_configs(@extra);

Load up configuration from known locations (warn if .csshrc file found) and 
load in option files as necessary.

=item $config->write_user_config_file();

Write out default $HOME/.clusterssh/config file (before option config files
are loaded).

=item $config->dump()

Write currently defined configuration to STDOUT

=back
