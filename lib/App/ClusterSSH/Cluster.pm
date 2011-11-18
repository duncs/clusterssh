package App::ClusterSSH::Cluster;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;
use Try::Tiny;

use base qw/ App::ClusterSSH::Base /;

our $master_object_ref;

sub new {
    my ( $class, %args ) = @_;

    if ( !$master_object_ref ) {
        $master_object_ref = $class->SUPER::new(%args);
    }

    return $master_object_ref;
}

#use overload (
#    q{""} => sub {
#        my ($self) = @_;
#        return $self->{hostname};
#    },
#    fallback => 1,
#);

1;

=pod

=head1 NAME

App::ClusterSSH::Cluster

=head1 SYNOPSIS

=head1 DESCRIPTION

Object representing application configuration

=head1 METHODS

=over 4

=item $host=ClusterSSH::Cluster->new();

Create a new object.

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
