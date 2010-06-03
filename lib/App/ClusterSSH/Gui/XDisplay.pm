package App::ClusterSSH::Gui::XDisplay;

use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;
use X11::Protocol;

use base qw/ X11::Protocol App::ClusterSSH::Base /;

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{x11} = X11::Protocol->new();

    if ( !$self->{x11} ) {
        croak 'Failed to get X connection', $/;
    }

    return $self;
}

sub xdisplay {
    my ($self) = @_;
    return $self->{x11};
}

sub get_font_size() {
    my ($self, $terminal_font) = @_;
    $self->debug( 2, "Fetching font size" );

    # get atom name<->number relations
    my $quad_width = $self->xdisplay->atom("QUAD_WIDTH");
    my $pixel_size = $self->xdisplay->atom("PIXEL_SIZE");

    my $font = $self->xdisplay->new_rsrc;
    $self->xdisplay->OpenFont( $font, $terminal_font );

    my %font_info;

    eval { (%font_info) = $self->xdisplay->QueryFont($font); }
        || die( "Fatal: Unrecognised font used ($terminal_font).\n"
            . "Please amend \$HOME/.csshrc with a valid font (see man page).\n"
        );

    my $internal_font_width  = $font_info{properties}{$quad_width};
    my $internal_font_height = $font_info{properties}{$pixel_size};

    if ( !$internal_font_width || !$internal_font_height ) {
        die(      "Fatal: Unrecognised font used ($terminal_font).\n"
                . "Please amend \$HOME/.csshrc with a valid font (see man page).\n"
        );
    }

    $self->debug( 2, "Done with font size" );
    return ( internal_font_width => $internal_font_width , internal_font_height=>$internal_font_height);
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
