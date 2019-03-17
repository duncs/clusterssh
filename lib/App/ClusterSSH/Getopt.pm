use strict;
use warnings;

package App::ClusterSSH::Getopt;

# ABSTRACT: App::ClusterSSH::Getopt - module to process command line args

=head1 SYNOPSIS

=head1 DESCRIPTION

Object representing application configuration

=cut

use Carp;
use Try::Tiny;
use Pod::Usage;
use Getopt::Long 2.48 qw(:config no_ignore_case bundling no_auto_abbrev);
use FindBin qw($Script);

use base qw/ App::ClusterSSH::Base /;

sub new {
    my ( $class, %args ) = @_;

    # basic setup that is over-rideable by each script as needs may be
    # different depending on the command used
    my %setup = (
        usage => [
            '-h|--help', '[options] [[user@]<server>[:port]|<tag>] [...] ',
        ],
    );

    my $self = $class->SUPER::new( %setup, %args );

    # options common to all connection types
    $self->{command_options} = {};
    $self->add_common_options;

    return $self;
}

sub add_option {
    my ( $self, %args ) = @_;
    my $spec = $args{spec};
    if ( !$spec ) {
        croak(
            App::ClusterSSH::Exception::Getopt->throw(
                error => 'No "spec" passed to add_option',
            ),
        );
    }
    my ( $option, $arg ) = $spec =~ m/^(.*?)(?:[\+=:](.*))?$/;
    if ($arg) {
        my $arg_open  = '<';
        my $arg_close = '>';
        if ( $args{arg_optional} ) {
            $arg_open  = '[';
            $arg_close = ']';
        }
        my $arg_type
            = defined $args{arg_desc}
            ? "${arg_open}$args{arg_desc}${arg_close}"
            : undef;
        $arg =~ s/\+/[[...] || <INTEGER>]/g;
        if ( $arg eq 'i' ) {
            $arg
                = defined $arg_type
                ? $arg_type
                : $arg_open . $self->loc('INTEGER') . $arg_close;
        }
        if ( $arg eq 's' ) {
            $arg
                = defined $arg_type
                ? "'$arg_type'"
                : "'" . $arg_open . $self->loc('STRING') . $arg_close . "'";
        }
    }
    my ( $desc, $long, $short, $accessor );
    foreach my $item ( split /\|/, $option ) {
        $desc .= ', ' if ($desc);

        # assumption - long options are 2 or more chars
        if ( length($item) == 1 ) {
            $desc .= "-$item";
            $short = "-$item";
        }
        else {
            $desc .= "--$item";
            $long = "--$item";
            if ( !$accessor ) {
                $accessor = $item;
            }
        }
        $desc  .= " $arg" if ($arg);
        $short .= " $arg" if ( $short && $arg );
        $long  .= " $arg" if ( $long && $arg );
    }
    $args{option_desc}  = $desc;
    $args{option_short} = $short;
    $args{option_long}  = $long;
    $args{accessor}     = $accessor if ( !defined $args{no_accessor} );

    $self->{command_options}->{$spec} = \%args;
    return $self;
}

# For options common to everything
sub add_common_options {
    my ($self) = @_;

    $self->add_option(
        spec        => 'version|v',
        help        => $self->loc("Show version information and exit"),
        no_accessor => 1,
    );
    $self->add_option(
        spec        => 'usage|?',
        help        => $self->loc('Show synopsis and exit'),
        no_accessor => 1,
    );
    $self->add_option(
        spec        => 'help|h',
        help        => $self->loc("Show basic help text and exit"),
        no_accessor => 1,
    );
    $self->add_option(
        spec => 'man|H',
        help => $self->loc("Show full help text (the man page) and exit"),
        no_accessor => 1,
    );
    $self->add_option(
        spec => 'debug:+',
        help => $self->loc(
            "Enable debugging.  Either a level can be provided or the option can be repeated multiple times.  Maximum level is 9."
        ),
        default => 0,
    );
    $self->add_option(
        spec        => 'generate-pod',
        no_accessor => 1,
        hidden      => 1,
    );
    $self->add_option(
        spec     => 'autoclose|K=i',
        arg_desc => 'seconds',
        help     => $self->loc(
            'Number of seconds to wait before closing finished terminal windows.'
        ),
    );
    $self->add_option(
        spec => 'autoquit|q',
        help => $self->loc(
            'Toggle automatically quitting after the last client window has closed (overriding the config file).'
        ),
    );
    $self->add_option(
        spec     => 'evaluate|e=s',
        arg_desc => '[user@]<host>[:port]',
        help     => $self->loc(
            'Display and evaluate the terminal and connection arguments to display any potential errors.  The <hostname> is required to aid the evaluation.'
        ),
    );
    $self->add_option(
        spec     => 'config-file|C=s',
        arg_desc => 'filename',
        help     => $self->loc(
            'Use supplied file as additional configuration file (see also L</"FILES">).'
        ),
    );
    $self->add_option(
        spec     => 'cluster-file|c=s',
        arg_desc => 'filename',
        help     => $self->loc(
            'Use supplied file as additional cluster file (see also L</"FILES">).'
        ),
    );
    $self->add_option(
        spec     => 'tag-file|r=s',
        arg_desc => 'filename',
        help     => $self->loc(
            'Use supplied file as additional tag file (see also L</"FILES">)'
        ),
    );
    $self->add_option(
        spec     => 'font|f=s',
        arg_desc => 'font',
        help     => $self->loc(
            'Specify the font to use in the terminal windows. Use standard X font notation such as "5x8".'
        ),
    );
    $self->add_option(
        spec => 'list|L:s',
        help => $self->loc(
            'List available cluster tags. Tag is optional.  If a tag is provided then hosts for that tag are listed.  NOTE: format of output changes when using "--quiet" or "-Q" option.'
        ),
        arg_desc     => 'tag',
        arg_optional => 1,
    );
    $self->add_option(
        spec => 'dump-config|d',
        help => $self->loc(
            'Dump the current configuration in the same format used by the F<$HOME/.clusterssh/config> file.'
        ),
    );
    $self->add_option(
        spec     => 'port|p=i',
        arg_desc => 'port',
        help     => $self->loc('Specify an alternate port for connections.'),
    );
    $self->add_option(
        spec => 'show-history|s',
        help => $self->loc('Show history within console window.'),
    );
    $self->add_option(
        spec => 'tile|g',
        help =>
            $self->loc('Toggle window tiling (overriding the config file).'),
    );
    $self->add_option(
        spec => 'term-args|t=s',
        help => $self->loc(
            'Specify arguments to be passed to terminals being used.'),
    );
    $self->add_option(
        spec     => 'title|T=s',
        arg_desc => 'title',
        help     => $self->loc(
            'Specify the initial part of the title used in the console and client windows.'
        ),
    );
    $self->add_option(
        spec => 'unique-servers|u',
        help => $self->loc(
            'Toggle connecting to each host only once when a hostname has been specified multiple times.'
        ),
    );
    $self->add_option(
        spec => 'use-all-a-records|A',
        help => $self->loc(
            'If a hostname resolves to multiple IP addresses, toggle whether or not to connect to all of them, or just the first one (see also config file entry).'
        ),
    );
    $self->add_option(
        spec => 'quiet|Q',
        help =>
            $self->loc('Do not output extra text when using some options'),
    );
    $self->add_option(
        spec     => 'cols|x=i',
        arg_desc => 'cols',
        help     => $self->loc('Number of columns'),
    );
    $self->add_option(
        spec     => 'rows|y=i',
        arg_desc => 'rows',
        help     => $self->loc('Number of rows'),
    );

    $self->add_option(
        spec => 'fillscreen',
        help => $self->loc(
            'Resize terminal windows to fill the whole available screen'),
    );

    return $self;
}

# For options common to ssh sessions
sub add_common_ssh_options {
    my ($self) = @_;

    $self->add_option(
        spec => 'options|o=s',
        help => $self->loc(
            'Specify arguments to be passed to ssh when making the connection.  B<NOTE:> options for ssh should normally be put into the ssh configuration file; see C<ssh_config> and F<$HOME/.ssh/config> for more details.'
        ),
        default => '-x -o ConnectTimeout=10',
    );

    return $self;
}

# For options that work in ssh, rsh type consoles, but not telnet or console
sub add_common_session_options {
    my ($self) = @_;

    $self->add_option(
        spec     => 'username|l=s',
        arg_desc => 'username',
        help     => $self->loc(
            'Specify the default username to use for connections (if different from the currently logged in user).  B<NOTE:> will be overridden by <user>@<host>.'
        ),
    );
    $self->add_option(
        spec     => 'action|a=s',
        arg_desc => 'command',
        help     => $self->loc(
            "Run the command in each session, e.g. C<-a 'vi /etc/hosts'> to drop straight into a vi session."
        ),
    );

    return $self;
}

sub getopts {
    my ($self) = @_;
    my $options = {};

    pod2usage( -verbose => 1 )
        if ( !GetOptions( $options, keys( %{ $self->{command_options} } ) ) );
    pod2usage( -verbose => 0 ) if ( $options->{'?'} || $options->{usage} );
    pod2usage( -verbose => 1 ) if ( $options->{'h'} || $options->{help} );
    pod2usage( -verbose => 2 ) if ( $options->{H}   || $options->{man} );

    # record what was given on the command line in case this
    # object is ever dumped out
    $self->{options_parsed} = $options;

    if ( $options->{'generate-pod'} ) {
        $self->_generate_pod;
        $self->exit;
    }

    if ( $options->{version} ) {
        print 'Version: ', $self->parent->VERSION, $/;
        $self->exit;
    }

    $options->{debug} ||= 0;
    $options->{debug} = 9 if ( $options->{debug} && $options->{debug} > 9 );

    # Now all options are set to the correct values, generate accessor methods
    foreach my $option ( sort keys( %{ $self->{command_options} } ) ) {

        # skip some accessors as they are already defined elsewhere
        next if $option =~ m/^(debug)\W/;

        my $accessor = $self->{command_options}->{$option}->{accessor};

        my $default = $self->{command_options}->{$option}->{default};

        if ( my $acc = $accessor ) {
            $accessor =~ s/-/_/g;
            no strict 'refs';

          # hide warnings when getopts is run multiple times, esp. for testing
            no warnings 'redefine';
            *$accessor = sub {
                return defined $options->{$acc} ? $options->{$acc} : $default;

    #                      defined $options->{$acc} ? $options->{$acc}
    #                    : defined $self->{command_options}->{$acc}->{default}
    #                    ? $self->{command_options}->{$acc}->{default}
    #                    : undef;
            };
            my $accessor_default = $accessor . '_default';
            *$accessor_default = sub { return $default; };
        }
    }

    $self->set_debug_level( $options->{debug} );

    $self->parent->config->load_configs( $self->config_file );

    if ( $self->use_all_a_records ) {
        $self->parent->config->{use_all_a_records}
            = !$self->parent->config->{use_all_a_records} || 0;
    }

    if ( $self->unique_servers ) {
        $self->parent->config->{unique_servers}
            = !$self->parent->config->{unique_servers} || 0;
    }

    $self->parent->config->{title} = $self->title if ( $self->title );
    $self->parent->config->{port}  = $self->port  if ( $self->port );

    # note, need to check if these actions can be performed as they are
    # not common acorss all communiction methods
    $self->parent->config->{command} = $self->action
        if ( $self->can('action') && $self->action );
    $self->parent->config->{user} = $self->username
        if ( $self->can('username') && $self->username );

    $self->parent->config->{terminal_font} = $self->font if ( $self->font );
    $self->parent->config->{terminal_args} = $self->term_args
        if ( $self->term_args );

    $self->parent->config->{show_history} = 1 if ( $self->show_history );

    $self->parent->config->{auto_close} = $self->autoclose
        if ( $self->autoclose );

    if ( $self->autoquit ) {
        $self->parent->config->{auto_quit}
            = !$self->parent->config->{auto_quit} || 0;
    }

    if ( $self->tile ) {
        $self->parent->config->{window_tiling}
            = !$self->parent->config->{window_tiling} || 0;
    }

    if ( $self->rows ) {
        $self->parent->config->{rows} = $self->rows;
    }
    if ( $self->cols ) {
        $self->parent->config->{cols} = $self->cols;
    }
    $self->parent->config->{fillscreen} = "yes"
        if ( $self->fillscreen );
    return $self;
}

sub output {
    my (@text) = @_;

    confess if ( exists $text[1] && !$text[1] );
    print @text, $/, $/;
}

# generate valid POD from all the options and send to STDOUT
# so build process can create pod files for the distribution
sub _generate_pod {
    my ($self) = @_;

    output $/ , "=pod";
    output '=head1 ',    $self->loc('NAME');
    output "$Script - ", $self->loc("Cluster administration tool");
    output '=head1 ',    $self->loc('VERSION');
    output $self->loc( "This documentation is for version: [_1]",
        $self->parent->VERSION );
    output '=head1 ', $self->loc('SYNOPSIS');

    # build the synopsis
    print "$Script ";
    foreach my $longopt ( sort keys( %{ $self->{command_options} } ) ) {
        next if ( $self->{command_options}->{$longopt}->{hidden} );

        print '['
            . (    $self->{command_options}->{$longopt}->{option_short}
                || $self->{command_options}->{$longopt}->{option_long} )
            . '] ';
    }
    print $/, $/;

    output '=head1 ', $self->loc('DESCRIPTION');
    output $self->loc(
        q{The command opens an administration console and an xterm to all specified hosts.  Any text typed into the administration console is replicated to all windows.  All windows may also be typed into directly.

This tool is intended for (but not limited to) cluster administration where the same configuration or commands must be run on each node within the cluster.  Performing these commands all at once via this tool ensures all nodes are kept in sync.

Connections are opened using [_1] which must be correctly installed and configured.

Extra caution should be taken when editing files as lines may not necessarily be in the same order;  assuming line 5 is the same across all servers and modifying that is dangerous.  It's better to search for the specific line to be changed and double-check all terminals are as expected before changes are committed.},
        $self->parent->config->{comms}
    );

    output '=head2 ', $self->loc('Further Notes');
    output $self->loc('Please also see "KNOWN BUGS".');
    output '=over';
    output '=item *';
    output $self->loc(
        q{The dotted line on any sub-menu is a tear-off, i.e. click on it and the sub-menu is turned into its own window.}
    );
    output '=item *';
    output $self->loc(
        q{Unchecking a hostname on the Hosts sub-menu will unplug the host from the cluster control window, so any text typed into the console is not sent to that host.  Re-selecting it will plug it back in.}
    );
    output '=item *';
    output $self->loc(
        q{If your window manager menu bars are obscured by terminal windows see the C<screen_reserve_XXXXX> options in the [_1] file (see [_2]).},
        'F<$HOME/.clusterssh/config>', 'L</"FILES">'
    );
    output '=item *';
    output $self->loc(
        q{If the terminals overlap too much see the C<terminal_reserve_XXXXX> options in the [_1] file (see [_2]).},
        'F<$HOME/.clusterssh/config>', 'L</"FILES">'
    );
    output '=item *';
    output $self->loc(
        q{When using ClusterSSH on a large number of systems to connect to a single system using an SSH utility (e.g. you issue a command to to copy a file using scp from the remote computers to a single host) and when these connections require authentication (i.e. you are going to authenticate with a password), the sshd daemon at that location may refuse connections after the number C<MaxStartups> limit in F<sshd_config> is exceeded.  (If this value is not set, it defaults to 10).  This is expected behavior; sshd uses this mechanism to prevent DoS attacks from unauthenticated sources.  Please tune sshd_config and reload the SSH daemon, or consider using the [_1] mechanism for authentication if you encounter this problem.},
        'F<~/.ssh/authorized_keys>'
    );
    output '=item *';
    output $self->loc(
        q{If client windows fail to open, try running:

[_1]

This will test the mechanisms used to open windows to hosts.  This could be due to either the [_2] terminal option which enables [_3] (some terminals do not require this option, other terminals have another method for enabling it - see your terminal documentation) or the configuration of [_4].},
        "C<< $Script -e {single host name} >>", 'C<-xrm>',
        'C<AllowSendEvents>',
        'C<' . $self->parent->config->{comms} . '>',
    );
    output '=back';

    output '=head1 ' . $self->loc('OPTIONS');
    output $self->loc(
        "Some of these options may also be defined within the configuration file.  Default options are shown as appropriate."
    );

    output '=over';
    foreach my $longopt ( sort keys( %{ $self->{command_options} } ) ) {
        next if ( $self->{command_options}->{$longopt}->{hidden} );

        output '=item ', $self->{command_options}->{$longopt}->{option_desc};
        output $self->{command_options}->{$longopt}->{help} || 'No help';

        if ( $self->{command_options}->{$longopt}->{default} ) {
            output $self->loc('Default'), ': ',
                $self->{command_options}->{$longopt}->{default}, $/, $/;
        }
    }
    output '=back';

    output '=head1 ' . $self->loc('ARGUMENTS');
    output $self->loc('The following arguments are supported:');
    output '=over';
    output '=item [user@]<hostname>[:port] ...';
    output $self->loc(
        'Open an xterm to the given hostname and connect to the administration console.  The optional port number can be used if the server is not listening on the standard port.'
    );
    output '=item <tag> ...';
    output $self->loc(
        'Open a series of xterms defined by <tag> in one of the supplementary configuration files (see [_1]).

B<Note:> specifying a username on a cluster tag will override any usernames defined in the cluster.',
        'L</"FILES">'
    );
    output '=back';

    output '=head1 ' . $self->loc('KEY SHORTCUTS');
    output $self->loc(
        'The following key shortcuts are available within the console window, and all of them may be changed via the configuration files.'
    );
    output '=over';
    output '=item  ', $self->parent->config->{key_addhost};
    output $self->loc(
        q{Open the 'Add Host(s) or Cluster(s)' dialogue box.  Multiple host or cluster names can be entered, separated by spaces.}
    );
    output '=item ', $self->parent->config->{key_clientname};
    output $self->loc(
        q{Paste in the hostname part of the specific connection string to each client, minus any username or port, e.g.

C<< scp /etc/hosts server:files/<Alt-n>.hosts >>

would replace the <Alt-n> with the client's name in each window.}
    );
    output '=item ', $self->parent->config->{key_localname};
    output $self->loc(
        q{Paste in the hostname of the server cssh is being run on});
    output '=item ', $self->parent->config->{key_quit};
    output $self->loc(
        'Quit the program and close all connections and windows.');
    output '=item ', $self->parent->config->{key_retilehosts};
    output $self->loc(q{Retile all the client windows.});
    output '=item ', $self->parent->config->{key_username};
    output $self->loc(q{Paste in the username for the connection});
    output '=back';

    output '=head1 ' . $self->loc('EXAMPLES');
    output '=over';
    output '=item ', $self->loc(q{Open up a session to 3 servers});
    output q{S<$ } . $Script . q{ server1 server2 server3>};
    output '=item ',
        $self->loc(
        q{Open up a session to a cluster of servers identified by the tag 'farm1' and give the controlling window a specific title, where the tag is defined in one of the default configuration files}
        );
    output q{S<$ } . $Script . q{ -T 'Web Farm Cluster 1' farm1>};
    output '=item ',
        $self->loc(
        q{Connect to different servers using different login names.  NOTE: this can also be achieved by setting up appropriate options in the configuration files.  Do not close the console when the last terminal exits.}
        );
    output q{S<$ } . $Script . q{ user1@server1 admin@server2>};
    output '=item ',
        $self->loc(
        q{Open up a cluster defined in a non-default configuration file});
    output q{S<$ } . $Script . q{ -c $HOME/cssh.extra_clusters db_cluster>};
    output '=item ',
        $self->loc(
        q{Override the configured/default port to use 2022 instead});
    output q{S<$ } . $Script . q{ -p 2022 server1 server2>};
    output '=back';

    output '=head1 ' . $self->loc('FILES');
    output '=over';
    output q{=item F</etc/clusters>, F<$HOME/.clusterssh/clusters>};
    output $self->loc(
        q{These files contain a list of tags to server names mappings.  When any name is used on the command line it is checked to see if it is a tag.  If it is a tag, then the tag is replaced with the list of servers.  The format is as follows:}
    );
    output 'S<< <tag> [user@]<server>[:port] [user@]<server>[:port] [...] >>';
    output $self->loc(
        'e.g.

    # List of servers in live
    live admin1@server1 admin2@server2:2022 server3 server4'
    );
    output $self->loc(
        q{All comments (marked by a #) and blank lines are ignored.  Tags may be nested, but be aware of using recursive tags as they are not checked for.}
    );
    output $self->loc(q{Servers can be defined using expansion macros:});
    output 'C<< webservers websvr{a,b,c} >>';
    output $self->loc(q{would be expanded to});
    output 'C<< webservers websvra websvrb websvrc >>';
    output $self->loc(q{and});
    output 'C<< webservers websvr{6..9} >>';
    output $self->loc(q{would be expanded to});
    output 'C<< webservers websvr6 websvr7 websvr8 websvr9 >>';

    output $self->loc(
        q{Extra cluster files may also be specified either as an option on the command line (see [_1]) or in the user's [_2] file (see [_3] configuration option).},
        'C<cluster-file>',
        'F<$HOME/.clusterssh/config>',
        'L</extra_cluster_file>'
    );
    output $self->loc(
        'B<NOTE:> the last tag read overwrites any pre-existing tag of that name.'
    );
    output $self->loc(
        'B<NOTE:> there is a special cluster tag called [_1] - any tags or hosts included within this tag will be automatically opened if nothing is specified on the command line.',
        'C<default>'
    );

    output q{=item F</etc/tags>, F<$HOME/.clusterssh/tags>};
    output $self->loc(
        q{Very similar to [_1] files but the definition is reversed.  The format is:},
        'F<clusters>'
    );
    output 'S<< <host> <tag> [...] >>';
    output $self->loc(
        q{This allows one host to be specified as a member of a number of tags.  This format can be clearer than using [_1] files.},
        'F<clusters>'
    );
    output $self->loc(
        q{Extra tag files may be specified either as an option (see [_1]) or within the user's [_2] file (see [_3] configuration option).},
        'C<tag-file>', 'F<$HOME/.clusterssh/config>', 'C<extra_tag_file>'
    );
    output $self->loc('B<NOTE:> All tags are added together');

    output q{=item F</etc/csshrc> & F<$HOME/.clusterssh/config>};
    output $self->loc(
        q{This file contains configuration overrides - the defaults are as marked.  Default options are overwritten first by the global file, and then by the user file.}
    );
    output $self->loc(
        'B<NOTE:> values for entries do not need to be quoted unless it is required for passing arguments, e.g.'
    );
    output
        q{C<< terminal_allow_send_events="-xrm '*.VT100.allowSendEvents:true'" >>};
    output $self->loc('should be written as');
    output
        q{C<< terminal_allow_send_events=-xrm '*.VT100.allowSendEvents:true' >>};

    output '=over';

    output '=item auto_close = 5';
    output $self->loc(
        'Close terminal window after this many seconds.  If set to 0 will instead wait on input from the user in each window before closing. See also [_1] and [_2]',
        'L<--autoclose>', '--no-autoclose'
    );

    output '=item auto_quit = 1';
    output $self->loc(
        'Automatically quit after the last client window closes.  Set to 0 to disable.  See also [_1]',
        'L<--autoquit>',
    );

    output '=item auto_wm_decoration_offsets = no';
    output $self->loc(
        'Enable or disable alternative algorithm for calculating terminal positioning.',
    );

    output '=item comms = ' . $self->parent->config->{comms};
    output $self->loc(
        'Sets the default communication method (initially taken from the name of the program, but can be overridden here).'
    );

    output '=item console_position = <null>';
    output $self->loc(
        q{Set the initial position of the console - if empty then let the window manager decide.  Format is '+<x>+<y>', i.e. '+0+0' is top left hand corner of the screen, '+0-70' is bottom left hand side of screen (more or less).}
    );

    output '=item external_command_mode = 0600';
    output $self->loc(q{File mode bits for the external_command_pipe.});

    output '=item external_command_pipe = <null>';
    output $self->loc(
        q{Define the full path to an external command pipe that can be written to for controlling some aspects of ClusterSSH, such as opening sessions to more clusters.

Commands:

C<< open <tag|hostname> >> - open new sessions to provided tag or hostname

C<< retile >> - force window retiling

e.g.: C<< echo 'open localhost' >> /path/to/external_command_pipe >>}
    );

    output '=item external_cluster_command = <null>';
    output $self->loc(
        q{Define the full path to an external command that can be used to resolve tags to host names.  This command can be written in any language.  The script must accept a list of tags to resolve and output a list of hosts (space separated on a single line).  Any tags that cannot be resolved should be returned unchanged.

A non-0 exit code will be counted as an error, a warning will be printed and output ignored.

If the external command is given a C<-L> option it should output a list of tags (space separated on a single line) it can resolve}
    );

    output '=item extra_cluster_file = <null>';
    output $self->loc(
        q{Define an extra cluster file in the format of [_1].  Multiple files can be specified, separated by commas.  Both ~ and $HOME are acceptable as a reference to the user's home directory, e.g.},
        'F</etc/clusters>'
    );
    output 'C<< extra_cluster_file = ~/clusters, $HOME/clus >>';

    output '=item extra_tag_file = <null>';
    output $self->loc(
        q{Define an extra tag file in the format of [_1].  Multiple files can be specified, separated by commas.  Both ~ and $HOME are acceptable as a reference to the user's home directory, e.g.},
        'F</etc/tags>'
    );
    output 'C<< extra_tag_file = ~/tags, $HOME/tags >>';

    output '=item key_addhost = Control-Shift-plus';
    output $self->loc(
        q{Default key sequence to open AddHost menu.  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item hide_menu = 0';
    output $self->loc(
        q{If set to 1, hide the menu bar (File, Hosts, Send, Help) in the console.},
    );

    output '=item key_clientname = Alt-n';
    output $self->loc(
        q{Default key sequence to send cssh client names to client.  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item key_localname = Alt-l';
    output $self->loc(
        q{Default key sequence to send hostname of local server to client.  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item key_paste = Control-v';
    output $self->loc(
        q{Default key sequence to paste text into the console window.  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item key_quit = Control-q';
    output $self->loc(
        q{Default key sequence to quit the program (will terminate all open windows).  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item key_retilehosts = Alt-r';
    output $self->loc(
        q{Default key sequence to retile host windows.  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item key_username = Alt-u';
    output $self->loc(
        q{Default key sequence to send username to client.  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item macro_servername = %s';
    output '=item macro_hostname = %h';
    output '=item macro_username = %u';
    output '=item macro_newline = %n';
    output '=item macro_version = %v';
    output $self->loc(
        q{Change the replacement macro used when either using a 'Send' menu item, or when pasting text into the main console.}
    );

    output '=item macros_enabled = yes';
    output $self->loc(
        q{Enable or disable macro replacement.  Note: this affects all the [_1] variables above.},
        'C<macro_*>'
    );

    output '=item max_addhost_menu_cluster_items = 6';
    output $self->loc(
        q{Maximum number of entries in the 'Add Host' menu cluster list before scrollbars are used}
    );

    output '=item max_host_menu_items = 30';
    output $self->loc(
        q{Maximum number of hosts to put into the host menu before starting a new column}
    );

    output '=item menu_host_autotearoff = 0';
    output '=item menu_send_autotearoff = 0';
    output $self->loc(
        q{When set to non-0 will automatically tear-off the host or send menu at program start}
    );

    output '=item mouse_paste = Button-2 (middle mouse button)';
    output $self->loc(
        q{Default key sequence to paste text into the console window using the mouse.  See [_1] for more information.},
        'L<KEY SHORTCUTS>'
    );

    output '=item rsh = /path/to/rsh';
    output '=item ssh = /path/to/ssh';
    output '=item telnet = /path/to/telnet';
    output $self->loc(
        q{Set the path to the specific binary to use for the communication method, else uses the first match found in [_1]},
        'C<$PATH>'
    );

    output '=item rsh_args = <blank>';
    output '=item ssh_args = "-x -o ConnectTimeout=10"';
    output '=item telnet_args = <blank>';
    output $self->loc(
        q{Sets any arguments to be used with the communication method (defaults to ssh arguments).

B<NOTE:> The given defaults are based on OpenSSH, not commercial ssh software.

B<NOTE:> Any "generic" change to the method (e.g., specifying the ssh port to use) should be done in the medium's own config file (see [_1] and [_2]).},
        'C<ssh_config>', 'F<$HOME/.ssh/config>'
    );

    output '=item screen_reserve_top = 0';
    output '=item screen_reserve_bottom = 60';
    output '=item screen_reserve_left = 0';
    output '=item screen_reserve_right = 0';
    output $self->loc(
        q{Number of pixels from the screen's side to reserve when calculating screen geometry for tiling.  Setting this to something like 50 will help keep cssh from positioning windows over your window manager's menu bar if it draws one at that side of the screen.}
    );

    output '=item terminal = /path/to/xterm';
    output $self->loc(q{Path to the X-Windows terminal used for the client.});

    output '=item terminal_args = <blank>';
    output $self->loc(
        q{Arguments to use when opening terminal windows.  Otherwise takes defaults from [_1] or [_2] file.},
        'F<$HOME/.Xdefaults>', 'F<$HOME/.Xresources>'
    );

    output '=item terminal_chdir = 0';
    output $self->loc(
        q{When non-0, set the working directory for each terminal as per '[_1]'},
        'L<terminal_chdir_path>'
    );

    output '=item terminal_chdir_path = $HOME/.clusterssh/work/%s';
    output $self->loc(
        q{Path to use as working directory for each terminal when '[_1]' is enabled.  The path provided is passed through the macro parser (see the section above on '[_2]'.},
        'L<terminal_chdir>', 'L<macros_enabled>',
    );

    output '=item terminal_font = 6x13';
    output $self->loc(
        q{Font to use in the terminal windows.  Use standard X font notation.}
    );

    output '=item terminal_reserve_top = 5';
    output '=item terminal_reserve_bottom = 0';
    output '=item terminal_reserve_left = 5';
    output '=item terminal_reserve_right = 0';
    output $self->loc(
        q{Number of pixels from the terminal's side to reserve when calculating screen geometry for tiling.  Setting these will help keep cssh from positioning windows over your scroll and title bars or otherwise overlapping the windows too much.}
    );

    output '=item terminal_colorize = 1';
    output $self->loc(
        q{If set to 1 (the default), then "-bg" and "-fg" arguments will be added to the terminal invocation command-line.  The terminal will be colored in a pseudo-random way based on the host name; while the color of a terminal is not easily predicted, it will always be the same color for a given host name.  After a while, you will recognize hosts by their characteristic terminal color.}
    );

    output '=item terminal_bg_style = dark';
    output $self->loc(
        q{If set to [_1], the terminal background will be set to black and the foreground to the pseudo-random color.  If set to [_2], then the foreground will be black and the background the pseudo-random color.  If terminal_colorize is [_3], then this option has no effect.},
        'C<dark>', 'C<light>', 'C<zero>'
    );

    output '=item terminal_size = 80x24';
    output $self->loc(
        q{Initial size of terminals to use. NOTE: the number of lines (24) will be decreased when resizing terminals for tiling, not the number of characters (80).}
    );

    output '=item terminal_title_opt = -T';
    output $self->loc(
        q{Option used with [_1] to set the title of the window},
        'C<terminal>' );

    output
        q{=item terminal_allow_send_events = -xrm '*.VT100.allowSendEvents:true'};
    output $self->loc(
        q{Option required by the terminal to allow XSendEvents to be received}
    );

    output '=item title = cssh';
    output $self->loc(
        q{Title of windows to use for both the console and terminals.});

    output '=item unmap_on_redraw = no';
    output $self->loc(
        q{Tell Tk to use the UnmapWindow request before redrawing terminal windows.  This defaults to "no" as it causes some problems with the FVWM window manager.  If you are experiencing problems with redraws, you can set it to "yes" to allow the window to be unmapped before it is repositioned.}
    );

    output '=item use_all_a_records = 0';
    output $self->loc(
        q{If a hostname resolves to multiple IP addresses, set to [_1] to connect to all of them, not just the first one found.  See also [_2]},
        'C<1>', 'C<--use-all-a-records>}'
    );

    output '=item use_hotkeys = 1';
    output $self->loc( q{Setting to [_1] will disable all hotkeys.}, 'C<0>' );

    output '=item use_natural_sort = 0';
    output $self->loc(
        q{Windows will normally sort in alphabetical order, i.e.: host1, host11, host2.  Setting to this [_1] will change the sort order, i.e.: host1, host2, host11. NOTE: You must have the perl module [_2] installed.},
        'C<1>', 'L<Sort::Naturally>'
    );

    output '=item user = $LOGNAME';
    output $self->loc(
        q{Sets the default user for running commands on clients.});

    output '=item window_tiling = 1';
    output $self->loc( q{Perform window tiling (set to [_1] to disable)},
        'C<0>' );

    output '=item window_tiling_direction = right';
    output $self->loc(
        q{Direction to tile windows, where [_1] means starting top left and moving right and then down, and anything else means starting bottom right and moving left and then up},
        'C<right>'
    );

    output '=back';

    output $self->loc(
        q{B<NOTE:> The key shortcut modifiers must be in the form [_1], [_2] or [_3], e.g. with the first letter capitalised and the rest lower case.  Keys may also be disabled individually by setting to the word [_4].},
        'C<Control>', 'C<Alt>', 'C<Shift>', 'C<null>'
    );

    output q{=item F<$HOME/.clusterssh/send_menu>};
    output $self->loc(
        q{This (optional) file contains items to populate the send menu.  The default entry could be written as:}
    );
    output '  <send_menu>
    <menu title="Use Macros">
        <toggle/>
        <accelerator>ALT-p</accelerator>
    </menu>
    <menu title="Remote Hostname">
        <command>%s</command>
        <accelerator>ALT-n</accelerator>
    </menu>
    <menu title="Local Hostname">
        <command>%s</command>
        <accelerator>ALT-l</accelerator>
    </menu>
    <menu title="Username">
        <command>%u</command>
        <accelerator>ALT-u</accelerator>
    </menu>
    <menu title="Test Text">
        <command>echo "ClusterSSH Version: %v%n</command>
    </menu>
  </send_menu>';

    output $self->loc(q{Submenus can also be specified as follows:});
    output '  <send_menu>
    <menu title="Default Entries">
      <detach>yes</detach>
      <menu title="Hostname">
          <command>%s</command>
          <accelerator>ALT-n</accelerator>
      </menu>
    </menu>
  </send_menu>';

    output $self->loc(q{B<Caveats:>});
    output '=over';
    output '=item ',
        $self->loc(
        q{There is currently no strict format checking of this file.});
    output '=item ',
        $self->loc(q{The format of the file may change in the future});
    output '=item ',
        $self->loc(
        q{If the file exists, the default entry (Hostname) is not added});
    output '=back';

    output $self->loc(
        q{The following replacement macros are available (note: these can be changed in the configuration file):}
    );
    output '=over';
    output '=item %s';
    output $self->loc(
        q{Hostname part of the specific connection string to each client, minus any username or port}
    );
    output '=item %u';
    output $self->loc(
        q{Username part of the connection string to each client});
    output '=item %h';
    output $self->loc(q{Hostname of server where cssh is being run from});
    output '=item %n';
    output $self->loc(q{C<RETURN> code});
    output '=back';

    output $self->loc( q{B<NOTE:> requires [_1] to be installed},
        'L<XML::Simple>' );

    output '=back';

    output '=head1 ', $self->loc('KNOWN BUGS');
    output $self->loc(
        q{If you have any ideas about how to fix the below bugs, please get in touch and/or provide a patch.}
    );
    output '=over';
    output '=item *';
    output $self->loc(
        q{Swapping virtual desktops can cause a redraw of all the terminal windows.  This is due to a lack of distinction within Tk between switching desktops and minimising/maximising windows.  Until Tk can tell the difference between the two events, there is no fix (apart from rewriting everything directly in X).}
    );
    output '=back';

    output '=head1 ', $self->loc('TROUBLESHOOTING');

    output $self->loc(
        q{If you have issues running [_1], first try:

[_2]

This performs two tests to confirm cssh is able to work properly with the settings provided within the [_3] file (or internal defaults).
}, $Script, 'C<< ' . $Script . ' -e [user@]<hostname>[:port] >>',
        'F<$HOME/.clusterssh/config>'
    );

    output '=over';
    output '=item 1';
    output $self->loc(
        q{Test the terminal window works with the options provided});
    output '=item 2';
    output $self->loc(
        q{Test [_1] works to a host with the configured arguments},
        $self->parent->config->{comms} );
    output '=back';

    output $self->loc(q{Configuration options to watch for in ssh are:});
    output '=over';
    output '=item *';
    output $self->loc(
        q{SSH doesn't understand [_1] - remove the option from the [_2] file},
        'C<-o ConnectTimeout=10>',
        'F<$HOME/.clusterssh/config>'
    );
    output '=item *';
    output $self->loc(
        q{OpenSSH-3.8 using untrusted ssh tunnels - use [_1] instead of [_2] or use [_3] in [_4] (if you change the default ssh options from [_5] to [_6])},
        'C<-Y>',
        'C<-X>',
        'C<ForwardX11Trusted yes>',
        'F<$HOME/.ssh/ssh_config>',
        'C<-x>',
        'C<-X>'
    );
    output '=back';

    output '=head1 ', $self->loc('SUPPORT AND REPORTING BUGS');

    output $self->loc(
        q{A web site for comments, requests, bug reports and bug fixes/patches is available at: [_1]},
        'L<https://github.com/duncs/clusterssh>'
    );

    output $self->loc(
        q{If you require support, please run the following commands and create an issue via: [_1]},
        'L<https://github.com/duncs/clusterssh/issues>',
    );
    output 'C<< perl -V >>';
    output q{C<< perl -MTk -e 'print $Tk::VERSION,$/' >>};
    output
        q{C<< perl -MX11::Protocol -e 'print $X11::Protocol::VERSION,$/' >>};
    output 'C<< cat /etc/csshrc $HOME/.clusterssh/config >>';

    output $self->loc(
        q{Using the debug option (--debug) will turn on debugging output.  Repeat the option to increase the amount of debug.  However, if possible please only use this option with one host at a time, e.g. [_1] due to the amount of output produced (in both main and child windows).},
        'C<< cssh --debug <host> >>'
    );

    output '=head1 ', $self->loc('SEE ALSO');
    output $self->loc(
        q{L<https://github.com/duncs/clusterssh/wiki/>,
C<ssh>,
L<Tk::overview>,
L<X11::Protocol>,
C<perl>}
    );

    output '=head1 ', $self->loc('AUTHOR');
    output 'Duncan Ferguson, C<< <duncan_j_ferguson at yahoo.co.uk> >>';

    output '=head1 ', $self->loc('LICENSE AND COPYRIGHT');
    output $self->loc(
        q{
Copyright 1999-2018 Duncan Ferguson.

This program is free software; you can redistribute it and/or modify it under the terms of either: the GNU General Public License as published by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
}
    );

    return $self;
}

1;

=head1 METHODS

=over 4

=item $obj=ClusterSSH::Getopts->new ({ })

Create a new object.

=item $obj=ClusterSSH::Getopts->add_option ({ })

Add extra options into the allowed set for parsing from the command line

=item $obj=ClusterSSH::Getopts->add_common_options ({ })

Add common options used by most calling scripts into the allowed set for
parsing from the command line

=item $obj=ClusterSSH::Getopts->add_common_session_options ({ })

Add common session options used by most calling scripts into the allowed
set for parsing from the command line

=item $obj=ClusterSSH::Getopts->add_common_ssh_options ({ })

Add common ssh options used by most calling scripts into the allowed
set for parsing from the command line

=item $obj->getopts

Function to call after all options have been set up; creates methods to
call for each option on the object, such as $obj->action, or $obj->username

=item output(@)

Simple helper func to print out pod lines with double returns

=item help

=item usage

Functions to output help and usage instructions

=back
