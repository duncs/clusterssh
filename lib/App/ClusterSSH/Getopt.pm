package App::ClusterSSH::Getopt;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;
use Try::Tiny;
use Getopt::Long qw(:config no_ignore_case bundling no_auto_abbrev);

use base qw/ App::ClusterSSH::Base /;

my %command_options = (
    'debug:+' => {
        spec => 'debug:+',
        help =>
            "--debug [number]\n\tEnable debugging.  Either a level can be provided or the option can be repeated multiple times.  Maximum level is 4.",
        default => 0,
    },
    'd' => { help => "-d\n\tDEPRECATED.  See '--debug'.", },
    'D' => { help => "-D\n\tDEPRECATED.  See '--debug'.", },
    'help|h|?' =>
        { help => "--help, -h, -?\n\tShow basic help text and exit", },
    'version|v' =>
        { help => "--version, -v\n\tShow version information and exit", },
    'man|H' => {
        help => "--man, -H\n\tShow full help text (the man page) and exit",
    },
);

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

    return $self;
}

sub add_option {
    my ( $self, %args ) = @_;
    $command_options{ delete $args{spec} } = \%args;
    return $self;
}

sub add_common_ssh_options {
    my ( $self ) = @_;

    $self->add_option(
        spec => 'ssh_cmd1|c1',
        help => "--ssh_cmd1\n\tCommon ssh option 1",
    );
    
    $self->add_option(
        spec => 'ssh_cmd2|c2',
        help => "--ssh_cmd2\n\tCommon ssh option 2",
    );
    
    return $self;
}

sub getopts {
    my ($self) = @_;

    use Data::Dump qw(dump);
    warn "master: ", dump \%command_options;

    warn "ARGV: ", dump @ARGV;

    my $options = {};
    if ( !GetOptions( $options, keys(%command_options) ) ) {
        $self->_usage;
    }

    if ( $options->{help} ) {
        $self->_usage;
        $self->exit_prog;
    }

    if ( $options->{version} ) {
        print "Version: $VERSION\n";
        $self->exit_prog;
    }

    warn "end: ", dump $options;

    #die "and out";
    warn "WAS DEAD HERE";

    return $self;
}

sub _usage {
    my ($self) = @_;

    warn "**** USAGE ****";

    my $options_pod;
    $options_pod .= "=over\n\n";

    foreach my $option ( sort keys(%command_options) ) {
        my ( $short, $long )
            = $command_options{$option}{help} =~ m/^(.*)\n\t(.*)/;
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
    warn "options_pod=$options_pod";
    warn '#' x 60;
    my $main_pod = '';
    while (<main::DATA>) {
        $main_pod .= $_;
    }

#    warn "main_pod=$main_pod";

    $main_pod =~ s/%OPTIONS%/$options_pod/;

    die $main_pod;
    -return $self;
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
