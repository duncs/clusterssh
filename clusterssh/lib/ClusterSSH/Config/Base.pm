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

    sub get_filename {
        my ($self) = @_;
        return $filename_for{ $self->id };
    }

    sub _get_config_hash {
        my ($self) = @_;
        croak( $self->loc('This method should have been replaced') );
    }
}

1;
