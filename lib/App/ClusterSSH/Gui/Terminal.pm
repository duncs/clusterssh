package App::ClusterSSH::Gui::Terminal;

use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;

use base qw/ App::ClusterSSH::Base /;
use App::ClusterSSH::Gui::Terminal::Command;

our %terminal_id_for;

sub new {
    my ( $class, %args ) = @_;

    #    if ( !$args{command} ) {
    #        croak('"command" not provided');
    #    }

    if ( !$args{host} || ref $args{host} ne 'App::ClusterSSH::Host' ) {
        croak('"command" not provided or invalid');
    }

    my $self = $class->SUPER::new(%args);

    $self->{pipenm} = tmpnam();
    $self->debug( 4, 'Set temp name to ', $self->{pipenm} );
    mkfifo( $self->{pipenm}, 0600 ) or croak( 'Cannot create pipe: ', $! );

    $self->{pid} = fork();
    if ( !defined( $self->{pid} ) ) {
        croak( 'Could not fork: ', $! );
    }

    # NOTE: the pid is re-fetched from the xterm window (via helper_script)
    # later as it changes and we need an accurate PID as it is widely used

    if ( $self->{pid} == 0 ) {

        # this is the child
        # Since this is the child, we can mark any server unresolved without
        # affecting the main program
        $self->{command} = App::ClusterSSH::Terminal::Command->new();
        $self->debug( 4, 'Running: ', $self->{command} );
        exec($self->{command}, '-p','sdfsdf','options') == 0 or die( 'Exec failed: ', $! );
    }

    if ( !$terminal_id_for{ $args{host}->{hostname} } ) {
        $terminal_id_for{ $args{host}->{hostname} } = $self;
        $self->{id} = $terminal_id_for{ $args{host}->{hostname} };
    }
    else {
        my $count = 0;
        until ( !$terminal_id_for{ $args{host}->{hostname} . ' ' . $count } )
        {
            $count++;
        }
        $terminal_id_for{ $args{host}->{hostname} . ' ' . $count } = $self;
        $self->{id}
            = $terminal_id_for{ $args{host}->{hostname} . ' ' . $count };
    }
    return $self;
}

sub get_id {
    my ($self) = @_;
    return $self->{id};
}

sub get_pid {
    my ($self) = @_;
    return $self->{pid};
}

sub command {
    my ($self) = @_;
    return $self->{command};
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
