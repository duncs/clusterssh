# $Id: SSH.pm 231 2008-11-22 11:25:43Z duncan_ferguson $
package ClusterSSH::Config::File;
use strict;
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use Carp;
use English qw( -no_match_vars );
use IO::File;

use base qw/ ClusterSSH::Config::Base /;

{
    my %config_for;

    sub new {
        my ( $class, $arg_ref ) = @_;

        my $self = $class->SUPER::new($arg_ref);

        my $fh = IO::File->new( $self->get_filename, 'r' );
        if ( !$fh ) {
            croak( 'Unable to open file "', $self->get_filename . '": ', $@,
            );
        }

        while ( my $line = $fh->getline ) {
            next if ( $line =~ m/^\s*$/ );    # ignore blank lines
            next if ( $line =~ m/^\s*#/ );    # ignore comment lines

            $line =~ s/#.*//;                 # remove comments
            $line =~ s/\s*//;                 # remove trailnig whitespace

            chomp($line);

            my ( $key, $value ) = $line =~ m/^\s*(\S+)\s*=\s*(.*)\s*$/xsm;

            if ( !$key || !defined($value) ) {
                croak(
                    'Error reading "',
                    $self->get_filename . '": ',
                    'cannot parse "',
                    $line, '"'
                );
            }

            $config_for{ $self->id }{$key} = $value;
        }

        return $self;
    }

    sub get_config_hash {
        my ($self) = @_;
        return $config_for{ $self->id };
    }
}

1;

__END__

=pod

=head1 

ClusterSSH::Config::File

=head1 SYNOPSIS

    $obj = ClusterSSH::Config::File({ filename => '/path/to/file' });
    my $filename=$obj->get_filename;

=head1 DESCRIPTION

Read the given file and parse for configuration options.  See also 
L<ClusterSSH::Config::Base>.

=head1 METHODS

These extra methods are provided on the object

=over 4

=item $obj = ClusterSSH::Config::File->new({ filename => '/path/to/file' });

Reads the file for configuation options.

=item $obj->get_filename();

Returns filename object was created with.

=item %config = %{ $obj->get_config_hash };

Return a hash of configuration items from the given file

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
