package App::ClusterSSH::Gui;

use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;

use base qw/ App::ClusterSSH::Base /;
use App::ClusterSSH::Gui::XDisplay;

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new( %args );

    $self->{window_mgr} = App::ClusterSSH::Gui::XDisplay->new();

    if(! $self->{window_mgr} ) {
        croak 'Failed to get X connection', $/;
    }

    return $self;
}

sub xdisplay {
    my ($self) = @_;
    return $self->{ window_mgr };
}

1;

=pod

=head1 

ClusterSSH::Gui

=head1 SYNOPSIS

    use ClusterSSH::Gui

=head1 DESCRIPTION

Object for interacting with the user for both console and terminals

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
