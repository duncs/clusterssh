# $Id: SSH.pm 231 2008-11-22 11:25:43Z duncan_ferguson $
package ClusterSSH::Config::SSH;
use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;
use English qw( -no_match_vars );

use base qw/ ClusterSSH::Config::Base /;

{
    my %hostname_of;

    sub new {
        my ( $class, $arg_ref ) = @_;

        if ( !$arg_ref->{filename} ) {
            $arg_ref->{filename} = $ENV{HOME} . '/.ssh/config';
        }

        my $self = $class->SUPER::new($arg_ref);

        open my $ssh_config_fh, '<', $self->get_filename
            or croak( 'Unable to read ', $self->get_filename, ': ', $ERRNO );

        my @ssh_config = <$ssh_config_fh>;
        close $ssh_config_fh
            or croak 'Could not close ', $self->get_filename, ': ', $ERRNO;

        foreach (@ssh_config) {
            if (m/^\s*host\s+([\w\.-]+)/mxi) {
                $hostname_of{ $self->id }{$1} = 1;
            }
            else {
                next;
            }
        }

        return $self;
    }

    sub DESTROY {
        my ( $self, $arg_ref, ) = @_;
        delete $hostname_of{ $self->id };
        return;
    }

    sub is_valid_hostname {
        my ( $self, $hostname ) = @_;
        return defined $hostname_of{ $self->id }{$hostname} ? 1 : 0;
    }
}

1;

__END__

=pod

=head1 

ClusterSSH::Config::SSH

=head1 SYNOPSIS

    $obj = ClusterSSH::Config::SSH({ filename => '/path/to/file' });
    my $filename=$obj->get_filename;

=head1 DESCRIPTION

Read the given file and parse for configuration options.  See also 
L<ClusterSSH::Config::Base>.

=head1 METHODS

These extra methods are provided on the object

=over 4

=item $obj = ClusterSSH::Config::SSH->new({ filename => '/path/to/file' });

Reads the file for configuation options.  Filename is optional and defaults to
F<$HOME/.ssh/ssh_config>

=item $obj->get_filename();

Returns filename parsed for data.

=item if( $obj->is_valid_hostname( $hostname ) ....

Return true or false value (0 or 1) on whether or not the given hostname
is in the ssh configuration file.

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
