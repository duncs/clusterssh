package ClusterSSH::Config::Base;
use strict;
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use Carp;
use English qw( -no_match_vars );

use base qw/ ClusterSSH::Base /;

{
    my %filename_for;

    sub new {
        my ( $class, $arg_ref ) = @_;

        my $self = $class->SUPER::new($arg_ref);

        if ( !$arg_ref->{filename} ) {
            croak(
                $self->loc( 'Filename not provided to module [_1]', $class ),
            );
        }

        $filename_for{ $self->id } = $arg_ref->{filename};

        $self->debug( 3, 'Checking ', $filename_for{ $self->id } );

        if ( -e $filename_for{ $self->id } ) {
            if ( !-r $filename_for{ $self->id } ) {
                croak(
                    $self->loc(
                        'Unable to read [_1]',
                        $filename_for{ $self->id },
                    )
                );
            }
        }
        else {
            croak(
                $self->loc(
                    'File [_1] does not exist.',
                    $filename_for{ $self->id },
                )
            );
        }

        return $self;
    }

    sub DESTROY {
        my ($self) = @_;
        delete $filename_for{ $self->id };
        return;
    }

    sub get_filename {
        my ($self) = @_;
        return $filename_for{ $self->id };
    }

    sub get_config_hash {
        my ($self) = @_;
        croak( $self->loc('This method should have been replaced') );
    }
}

1;

__END__

=pod

=head1 

ClusterSSH::Config::Base

=head1 SYNOPSIS

    use base qw/ ClusterSSH::Config::Base /;

    # in object new method
    sub new {
        ( $class, $arg_ref ) = @_;
        my $self = $class->SUPER::new($arg_ref);
        return $self;
    }

=head1 DESCRIPTION

Base object to provide some utility functions on configuration objects 
that access files - should not be used directly.  See also L<ClusterSSH::Base>.

=head1 METHODS

These extra methods are provided on the object

=over 4

=item $obj = CLusterSSH::Config::Base->new({ filename => '/path/to/file' });

Creates object.  In higher debug levels the args are printed out.  Does some
basic checks to ensure the C<filename> exists.  Croaks on problems.

=item $obj->get_filename();

Returns filename object was created with.

=item %config = %{ $obj->get_config_hash };

Return a hash of configuration items from the given file.  Needs to be overidden
by child objects.

=back

=head1 AUTHOR
Duncan Ferguson (<duncan_j_ferguson (at) yahoo.co.uk>)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009 Duncan Ferguson (<duncan_j_ferguson (at) yahoo.co.uk>). 
All rights reserved

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
