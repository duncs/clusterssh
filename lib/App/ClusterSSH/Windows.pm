package App::ClusterSSH::Windows;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;
use Gtk2 -init;

use base qw/ App::ClusterSSH::Base /;

use App::ClusterSSH::Windows::Console;

our %windows;

sub new {
    my ( $class, %args ) = @_;

    #    if ( !$args{hostname} ) {
    #        croak(
    #            App::ClusterSSH::Exception->throw(
    #                error => $class->loc('hostname is undefined')
    #            )
    #        );
    #    }

    #    # remove any keys undef values - must be a better way...
    #    foreach my $remove (qw/ port username /) {
    #        if ( !$args{$remove} && grep {/^$remove$/} keys(%args) ) {
    #            delete( $args{$remove} );
    #        }
    #    }

    my $self = $class->SUPER::new(%args);

    $self->{console} = App::ClusterSSH::Windows::Console->new();

    return $self;
}

sub console {
    my ($self) = @_;
    return $self->{console};
}

sub enter_loop {
    my ($self) = @_;

    Gtk2->main;

    return $self;
}

1;

=pod

=head1 NAME

ClusterSSH::Windows - Object representing a terminal window.

=head1 SYNOPSIS

    use ClusterSSH::Windows;

=head1 DESCRIPTION

Object representing a terminal window. 

=head1 METHODS

=over 4

=item $window=ClusterSSH::Windows->new ({ something => 'something' })

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
