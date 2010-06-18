package App::ClusterSSH::Gui::Terminal::Command;

use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;

use base qw/ App::ClusterSSH::Base /;

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

use Data::Dump qw(dump);
die dump  \%args;

    return $self;
}

use overload (
    q{""} => sub {
        my ($self) = @_;
        return $self->{script};
    },
    fallback => 1,
);

sub script() {
    my ($self) = @_;

    # -p => pipe name
    # -s => server name
    # -u => username
    # -p => port
    # -c => command to run
    # -b => session binary (ssh, telnet, rsh, etc)
    # -a => session arguments
    my $script = <<'!EOF!';
    use strict;
    use Getopt::Std;
    my %o;
    getopts( "p:s:u:p:c:d:b:a:", \%o );

#    print "%_ => $o{$_}",$/ foreach (keys %o);

    if($o{p}) {
        open( my $pipe, ">", $o{p} ) or die( "Failed to open pipe: ", $!, $/ );
        print {$pipe} ($$, ":", $ENV{WINDOWID} || "ERROR")
            or die( "Failed to write to pipe: ", $!, $/ );
        close($pipe) or die( "Failed to close pipe: ", $!, $/ );
    }

    my $command = join( " ", $o{b}||" ", $o{a}||" ", );

    if ( $o{u} ) {
        if ( $o{b} && $o{b} !~ /telnet$/ ) {
            $command .= join( " ", "-l", $o{u} );
        }
    }

    if ( $o{b} && $o{b} =~ /telnet$/ ) {
        $command .= join( " ", $o{s}, $o{p} );
    }
    else {
        if ( $o{p} ) {
            $command .= join( " ", "-p", $o{p} );
        }
        if($o{s}) {
            $command .= $o{s};
        }
    }

    if($o{c}) {
        $command .= $o{c};
    }

    if ( $o{d} ) {
        warn( "Running: ", $command, $/ );
    }
    exec($command);
!EOF!
    eval $script;
    if ($@) {
        croak( 'Error in compiling helper script: ', $@ );
    }
    return $script;
}

1;

=pod

=head1 

ClusterSSH::Gui::Terminal

=head1 SYNOPSIS

    use ClusterSSH::Gui::Terminal;

=head1 DESCRIPTION

Object for creating and maintaining terminal session to server

=head1 METHODS

=over 4

=item $host=ClusterSSH::Gui->new()

=back

=head1 AUTHOR

Duncan Ferguson (<duncan_j_ferguson (at) yahoo.co.uk>)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Duncan Ferguson (<duncan_j_ferguson (at) yahoo.co.uk>). 
All rights reserved

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
