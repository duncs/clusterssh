use warnings;
use strict;
package App::ClusterSSH;

# ABSTRACT: Cluster administration tool
# ABSTRACT: Cluster administration tool

use version; our $VERSION = version->new('4.17');

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

=cut

use Carp qw/cluck :DEFAULT/;

use base qw/ App::ClusterSSH::Base /;
use App::ClusterSSH::Host;
use App::ClusterSSH::Config;
use App::ClusterSSH::Helper;
use App::ClusterSSH::Cluster;
use App::ClusterSSH::Getopt;
use App::ClusterSSH::Window;

use FindBin qw($Script);

use POSIX ":sys_wait_h";
use POSIX qw/:sys_wait_h strftime mkfifo/;
use File::Temp qw/:POSIX/;
use Fcntl;
use File::Basename;
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
    $self->{window}  = App::ClusterSSH::Window->new( parent => $self, );

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

sub window {
    my ($self) = @_;
    return $self->{window};
}

# Set up UTF-8 on STDOUT
binmode STDOUT, ":utf8";

#use bytes;

### all sub-routines ###

# catch_all exit routine that should always be used
sub exit_prog() {
    my ($self) = @_;
    $self->debug( 3, "Exiting via normal routine" );

    if ( $self->config->{external_command_pipe}
        && -e $self->config->{external_command_pipe} )
    {
        close( $self->{external_command_pipe_fh} )
            or warn(
            "Could not close pipe "
                . $self->config->{external_command_pipe} . ": ",
            $!
            );
        $self->debug( 2, "Removing external command pipe" );
        unlink( $self->config->{external_command_pipe} )
            || warn "Could not unlink "
            . $self->config->{external_command_pipe}
            . ": ", $!;
    }

    $self->window->terminate_all_hosts;

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
        @servers = $self->remove_repeated_servers(@servers);
    }

    $self->debug( 3, 'leaving with ', $_ ) foreach (@servers);
    $self->debug( 2, 'Resolving cluster names: completed' );
    return (@servers);
}

sub remove_repeated_servers {
    my $self = shift;
    my %all  = ();
    @all{@_} = 1;
    return ( keys %all );
}

sub run {
    my ($self) = @_;

    $self->getopts;

### main ###

    $self->window->initialise;

    $self->debug( 2, "VERSION: ", $__PACKAGE__::VERSION );

    # only use ssh_args from options if config file ssh_args not set AND
    # options is not the default value otherwise the default options
    # value is used instead of the config file
    if ( $self->config->{comms} eq 'ssh' ) {
        if ( defined $self->config->{ssh_args} ) {
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

    $self->config->dump() if ( $self->options->dump_config );

    $self->evaluate_commands() if ( $self->options->evaluate );

    $self->window->get_font_size();

    $self->window->load_keyboard_map();

    # read in normal cluster files
    $self->config->{extra_cluster_file} .= ',' . $self->options->cluster_file
        if ( $self->options->cluster_file );
    $self->config->{extra_tag_file} .= ',' . $self->options->tag_file
        if ( $self->options->tag_file );

    $self->cluster->get_cluster_entries( split /,/,
        $self->config->{extra_cluster_file} || '' );
    $self->cluster->get_tag_entries( split /,/,
        $self->config->{extra_tag_file} || '' );

    my @servers;

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

    $self->window->create_windows();
    $self->window->create_menubar();

    $self->window->change_main_window_title();

    $self->debug( 2, "Capture map events" );
    $self->window->capture_map_events();

    $self->debug( 0, 'Opening to: ', join( ' ', @servers ) )
        if ( @servers && !$self->options->quiet );
    $self->window->open_client_windows(@servers);

    # Check here if we are tiling windows.  Here instead of in func so
    # can be tiled from console window if wanted
    if ( $self->config->{window_tiling} eq "yes" ) {
        $self->window->retile_hosts();
    }
    else {
        $self->window->show_console();
    }

    $self->window->build_hosts_menu();

    $self->debug( 2, "Sleeping for a mo" );
    select( undef, undef, undef, 0.5 );

    $self->window->console_focus;

    # set up external command pipe
    if ( $self->config->{external_command_pipe} ) {

        if ( -e $self->config->{external_command_pipe} ) {
            $self->debug( 1, "Removing pre-existing external command pipe" );
            unlink( $self->config->{external_command_pipe} )
                or die(
                "Could not remove "
                    . $self->config->{external_command_pipe}
                    . " prior to creation: "
                    . $!,
                $/
                );
        }

        $self->debug( 2, "Creating external command pipe" );

        mkfifo(
            $self->config->{external_command_pipe},
            oct( $self->config->{external_command_mode} )
            )
            or die(
            "Could not create "
                . $self->config->{external_command_pipe} . ": ",
            $!
            );

        sysopen(
            $self->{external_command_pipe_fh},
            $self->config->{external_command_pipe},
            O_NONBLOCK | O_RDONLY
            )
            or die(
            "Could not open " . $self->config->{external_command_pipe} . ": ",
            $!
            );
    }

    $self->debug( 2, "Setting up repeat" );
    $self->window->setup_repeat();

    # Start event loop
    $self->debug( 2, "Starting MainLoop" );
    $self->window->mainloop();

    # make sure we leave program in an expected way
    $self->exit_prog();
}

1;


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

=item window

Method to access associated window module

=item write_default_user_config
                                           
=back

=head1 BUGS

Please report any bugs or feature requests via L<https://github.com/duncs/clusterssh/issues>. 

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::ClusterSSH

You can also look for information at:

=over 4

=item * Github issue tracker

L<https://github.com/duncs/clusterssh/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-ClusterSSH>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-ClusterSSH>

=item * Search CPAN

L<http://search.cpan.org/dist/App-ClusterSSH/>

=back

=head1 ACKNOWLEDGEMENTS

Please see the THANKS file from the original distribution.

=cut
