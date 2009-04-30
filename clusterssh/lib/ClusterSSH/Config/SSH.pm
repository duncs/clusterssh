# $Id: SSH.pm 231 2008-11-22 11:25:43Z duncan_ferguson $
package ClusterSSH::Config::SSH;
use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;
use English qw( -no_match_vars );

use base qw/ ClusterSSH::Base /;

{
    my %hostname_of;
    my $filename = $ENV{HOME} . '/.ssh/config';

    sub new {
        my ( $class, $arg_ref ) = @_;

        my $self = $class->SUPER::new($arg_ref);

        if ( $arg_ref->{filename} ) {
            $filename = $arg_ref->{filename};
        }

        if ( -e $filename ) {
            if ( !-f $filename ) {
                carp( 'Unable to read ', $filename );
                return;
            }
            if ( !-r $filename ) {
                carp( 'Unable to read ', $filename );
                return;
            }
            open my $ssh_config_fh, '<', $filename
                or croak( 'Unable to read ', $filename, ': ', $ERRNO );

            my @ssh_config = <$ssh_config_fh>;
            close $ssh_config_fh
                or croak 'Could not close ', $filename, ': ', $ERRNO;

            foreach (@ssh_config) {
                if (m/^\s*host\s+([\w\.-]+)/mxi) {
                    $hostname_of{ $self->id }{$1} = 1;
                }
                else {
                    next;
                }
            }
        }

        return $self;
    }

    sub get_filename {
        my ($self) = @_;
        return $filename;
    }

    sub is_valid_hostname {
        my ( $self, $hostname ) = @_;
        return defined $hostname_of{ $self->id }{$hostname} ? 1 : 0;
    }
}

1;
