package App::ClusterSSH::Getopt;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;
use Try::Tiny;
use Getopt::Long qw(:config no_ignore_case bundling no_auto_abbrev);
use FindBin qw($Script);

use base qw/ App::ClusterSSH::Base /;

sub new {
    my ( $class, %args ) = @_;

    # basic setup that is over-rideable by each script as needs may be
    # different depending ont he command used
    my %setup = (
        usage => '[options] [[user@]<server>[:port]|<tag>] [...]',
    );

    my $self = $class->SUPER::new(%setup, %args);

    # options common to all connection types
    $self->{command_options} = {};
    $self->add_common_options;

    return $self;
}

sub add_option {
    my ( $self, %args ) = @_;
    $self->{command_options}->{ delete $args{spec} } = \%args;
    return $self;
}

# For options common to everything
sub add_common_options {
    my ( $self ) = @_;

    $self->add_option(
        spec => 'help|h' ,
        help => $self->loc("Show help text and exit"),
    );
    $self->add_option(
        spec => 'usage|?' ,
        help => $self->loc('Show basic usage and exit'),
    );
    $self->add_option(
        spec => 'version|v' ,
        help => $self->loc("Show version information and exit"),
    );
    $self->add_option(
        spec => 'man|H' ,
        help => $self->loc("Show full help text (the man page) and exit"),
    );
    $self->add_option(
        spec => 'debug:+',
        help => $self->loc("Enable debugging.  Either a level can be provided or the option can be repeated multiple times.  Maximum level is 4."),
        default => 0,
    );
    $self->add_option(
        spec => 'generate-pod',
        hidden => 1,
    );
    $self->add_option(
        spec => 'autoclose|K=i',
        arg_desc => 'seconds',
        help => $self->loc('Number of seconds to wait before closing finished terminal windows.'),
    );
    $self->add_option(
        spec => 'autoquit|q',
        help => $self->loc('Enable automatically quiting after the last client window has closed (overriding the config file).  See also L<--no-autoquit>'),
    );
    $self->add_option(
        spec => 'no-autoquit|Q',
        help => $self->loc('Disable automatically quiting after the last client window has closed (overriding the config file).  See also L<--autoquit>'),
    );
    $self->add_option(
        spec => 'evaluate|e=s',
        arg_desc => '[user@]<host>[:port]',
        help => $self->loc('Display and evaluate the terminal and connection arguments to display any potential errors.  The <hostname> is required to aid the evaluation.'),
    );
    $self->add_option(
        spec => 'config-file|C=s',
        arg_desc => 'filename',
        help => $self->loc('Use supplied file as additional configuration file (see also L</"FILES">).'),
    );
    $self->add_option(
        spec => 'cluster-file|c=s',
        arg_desc => 'filename',
        help => $self->loc('Use supplied file as additional cluster file (see also L</"FILES">).'),
    );
    $self->add_option(
        spec => 'tag-file|r=s',
        arg_desc => 'filename',
        help => $self->loc('Use supplied file as additional tag file (see also L</"FILES">)'),
    );
    $self->add_option(
        spec => 'font|f=s',
        arg_desc => 'font',
        help => $self->loc('Specify the font to use in the terminal windows. Use standard X font notation such as "5x8".'),
    );
    $self->add_option(
        spec => 'list|L',
        help => $self->loc('List available cluster tags.'),
    );
    $self->add_option(
        spec => 'output-config|u',
        help => $self->loc('Output the current configuration in the same format used by the F<$HOME/.clusterssh/config> file.'),
    );
    $self->add_option(
        spec => 'port|p=i',
        arg_desc => 'port',
        help => $self->loc('Specify an alternate port for connections.'),
    );
    $self->add_option(
        spec => 'show-history|s',
        help => $self->loc('IN BETA: Show history within console window.  This code is still being worked upon, but may help some users.'),
    );
    $self->add_option(
        spec => 'tile|g',
        help => $self->loc('Enable window tiling (overriding the config file).  See also --no-tile.'),
    );
    $self->add_option(
        spec => 'no-tile|G',
        help => $self->loc('Disable window tiling (overriding the config file).  See also --tile.'),
    );
    $self->add_option(
        spec => 'term-args|t=s',
        help => $self->loc('Specify arguments to be passed to terminals being used.'),
    );
    $self->add_option(
        spec => 'title|T=s',
        arg_desc => 'title',
        help => $self->loc('Specify the initial part of the title used in the console and client windows.'),
    );
    $self->add_option(
        spec => 'unique-servers|m',
        help => $self->loc('Connect to each host only once.'),
    );
    $self->add_option(
        spec => 'use-all-a-records|A',
        help => $self->loc('If a hostname resolves to multiple IP addresses, toggle whether or not to connect to all of them, or just the first one (see also config file entry).'),
    );
    $self->add_option(
        spec => 'username|l=s',
        arg_desc => 'username',
        help => $self->loc('Specify the default username to use for connections (if different from the currently logged in user).  B<NOTE:> will be overridden by <user>@<host>.'),
    );
    
    return $self;
}

# For options common to ssh sessions
sub add_common_ssh_options {
    my ( $self ) = @_;

    $self->add_option(
        spec => 'options|o=s',
        help => $self->loc('Specify arguments to be passed to ssh when making the connection.  B<NOTE:> options for ssh should normally be put into the ssh configuration file; see C<ssh_config> and F<$HOME/.ssh/config> for more details.'),
        default => '-x -o ConnectTimeout=10',
    );

    return $self;
}

# For options that work in ssh, rsh type consoles, but not telnet or console
sub add_common_session_options {
    my ( $self ) = @_;

    $self->add_option(
        spec => 'action|a=s',
        arg_desc => 'command',
        help => $self->loc("Run the command in each session, e.g. C<-a 'vi /etc/hosts'> to drop straight into a vi session."),
    );

    return $self;
}

sub getopts {
    my ($self) = @_;

    use Data::Dump qw(dump);
    #warn "master: ", dump \%command_options;
    warn "ARGV: ", dump @ARGV;

    my $options = {};

    if ( !GetOptions( $options, keys(%{$self->{command_options}}) ) ) {
        $self->usage;
        $self->exit;
    }

    if ( $options->{'generate-pod'}) {
        $self->_generate_pod;
        $self->exit;
    }

    if ( $options->{usage} ) {
        $self->usage;
        $self->exit;
    }

    if ( $options->{help} ) {
        $self->help;
        $self->exit;
    }

    if ( $options->{version} ) {
        print "Version: $VERSION\n";
        $self->exit;
    }

    warn "end: ", dump $options;

    #die "and out";
    warn "WAS DEAD HERE";

    return $self;
}

sub usage {
    my ($self) = @_;

    #print $self->loc('US

    my $options_pod;
    $options_pod .= "=over\n\n";

    foreach my $option ( sort keys(%{ $self->{command_options}}) ) {
        my ( $short, $long )
            = $self->{command_options}{$option}{help} =~ m/^(.*)\n\t(.*)/;
        $options_pod .= "=item $short\n\n";
        $options_pod .= "$long\n\n";
    }
    $options_pod .= "=back\n\n";

#    my $common_pod;
#    while (<DATA>) {
#        $common_pod .= $_;
#    }
#
#    warn "common_pod=$common_pod";

#    warn '#' x 60;
##    warn "options_pod=$options_pod";
##    warn '#' x 60;
##    my $main_pod = '';
##    while (<main::DATA>) {
##        $main_pod .= $_;
##    }

#    warn "main_pod=$main_pod";

##    $main_pod =~ s/%OPTIONS%/$options_pod/;

 ##   die $main_pod;
    return $self;
}

sub help {
    my ($self) = @_;

    warn "** HELP **";

    return $self;
}

# generate valid POD from all the options and send to STDOUT
# so build process can create pod files for the distribution
sub _generate_pod {
    my ($self) = @_;

    warn "** GENERATE POD **";
    print $/ , "=pod",$/,$/;
    print '=head1 ',$self->loc('NAME'),$/,$/;
    print "$Script - ", $self->loc("Cluster administration tool"),$/,$/;
    print '=head1 ',$self->loc('SYNOPSIS'),$/,$/;
    print "S<< $Script $self->{usage} >>",$/,$/;
    print '=head1 ',$self->loc('DESCRIPTION'),$/,$/;
    print $self->loc("_DESCRIPTION"),$/,$/;

    $self->_pod_output_list_section(2,'Further Notes');

    print '=head1 '.$self->loc('OPTIONS'),$/,$/;
    print $self->loc("_OPTIONS"),$/,$/;

    print '=over',$/,$/;
    foreach my $longopt (sort keys(%{$self->{command_options}})) {
        next if($self->{command_options}->{$longopt}->{hidden});

        my ($option, $arg) = $longopt =~ m/^(.*?)(?:[=:](.*))?$/;
        if($arg) {
            my $arg_desc;
            if(my $desc=$self->{command_options}->{$longopt}->{arg_desc}) {
                $arg_desc="<$desc>";
            }
            $arg=~s/\+/[[...] || <INTEGER>]/g;
            $arg = $arg_desc || '<INTEGER>' if($arg eq 'i');
            if($arg eq 's'){
                if($arg_desc) {
                    $arg = "'$arg_desc'";
                } else {
                    $arg = "'<STRING>'" ;
                }
            }
            #$arg=~s/i/<INTEGER>/g;
            #$arg=~s/s/<STRING>/g;
        }
        my $desc;
        foreach my $item ( split /\|/, $option) {

            $desc .= ', ' if($desc);

            # assumption - long options are 2 or more chars
            if(length($item) == 1) {
                $desc .= "-$item";
            } else {
                $desc .= "--$item";
            }
            $desc .= " $arg" if($arg);
        }
        print '=item ', $desc, $/,$/;
        print $self->{command_options}->{$longopt}->{help},$/,$/;
    }
    print '=back',$/,$/;

    $self->_pod_output_list_section(1,'ARGUMENTS');
    $self->_pod_output_list_section(1,'KEY SHORTCUTS');
    $self->_pod_output_list_section(1,'EXAMPLES');

    return $self;
}

sub _pod_output_list_section {
    my ($self, $level, $section) = @_;

    print '=head'.$level.' ',$self->loc($section),$/,$/;
    $section=uc($section);
    $section=~s/ /_/g;
    print $self->loc('_'.$section),$/,$/;
    print '=over',$/,$/;
    for (1 .. 10) {
        # there might not be 10 sections so catch errors
        my ($name, $desc);
        eval {
            $name = $self->loc('_'.$section.'_NAME_'.$_);
        };
        eval {
            $desc=$self->loc('_'.$section.'_DESC_'.$_);
        };
        # and if there is an error we have gone past the last item
        #last if($@);
        if($desc) {
            print '=item ', $name || '*',$/,$/;
            print $desc,$/,$/;
        }
    }
    print '=back',$/,$/;

    return $self;
}

#use overload (
#    q{""} => sub {
#        my ($self) = @_;
#        return $self->{hostname};
#    },
#    fallback => 1,
#);

1;

__DATA__

=pod

=head1 NAME

App::ClusterSSH::Getopt - module to process command line args

=head1 SYNOPSIS

=head1 DESCRIPTION

Object representing application configuration

=head1 METHODS

=over 4

=item $host=ClusterSSH::Helper->new ({ })

Create a new helper object.

=item $host=ClusterSSH::Helper->script ({ })

Return the helper script

=back

=head1 AUTHOR

Duncan Ferguson, C<< <duncan_j_ferguson at yahoo.co.uk> >>

=head1 LICENSE AND COPYRIGHT

Copyright 1999-2010 Duncan Ferguson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
