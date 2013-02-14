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

sub get_clusters {
    my ( $self, @files ) = @_;

    for my $file ( '/etc/clusters', $ENV{HOME}.'/.clusterssh/clusters',@files ) {
        $self->debug(3, 'Loading in config from: ', $file);
        $self->read_cluster_file($file);
    }

    return $self;
}

sub read_cluster_file {
    my ( $self, $filename ) = @_;
    $self->debug( 2, 'Reading clusters from file ', $filename );

    if ( -f $filename ) {
        open( my $fh, '<', $filename )
            || croak(
            App::ClusterSSH::Exception::Cluster->throw(
                error => $self->loc(
                    'Unable to read file [_1]: [_2]',
                    $filename, $!
                )
            )
            );

        my $line;
        while ( defined( $line = <$fh> ) ) {
            next
                if ( $line =~ /^\s*$/ || $line =~ /^#/ )
                ;    # ignore blank lines & commented lines
            chomp $line;
            if ( $line =~ s/\\\s*$// ) {
                $line .= <$fh>;
                redo unless eof($fh);
            }
            my @line = split( /\s+/, $line );

        #s/^([\w-]+)\s*//;               # remote first word and stick into $1

            $self->debug( 3, "read line: $line" );
            $self->register_tag(@line);
        }

        close($fh);
    }
    else {
        $self->debug( 2, 'No file found to read');
    }
    return $self;
}

sub register_tag {
    my ( $self, $tag, @nodes ) = @_;

    $self->debug( 2, "Registering tag $tag: ", join( ' ', @nodes ) );

    $self->{$tag} = \@nodes;

    return $self;
}

sub get_tag {
    my ( $self, $tag ) = @_;

    if ( $self->{$tag} ) {
        $self->debug( 2, "Retrieving tag $tag: ",
            join( ' ', $self->{$tag} ) );

        return @{ $self->{$tag} };
    }

    $self->debug( 2, "Tag $tag is not registered" );
    return;
}

sub list_tags {
    my ($self) = @_;
    return keys(%$self);
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

App::ClusterSSH::Cluster - Object representing cluster configuration

=head1 SYNOPSIS

=head1 DESCRIPTION

Object representing application configuration

=head1 METHODS

=over 4

=item $cluster=ClusterSSH::Cluster->new();

Create a new object.  Object should be common across all invocations.

=item $cluster->get_clusters($filename);

Read in /etc/clusters and any other given file name and register the tags found.

=item $cluster->read_cluster_file($filename);

Read in the given cluster file and register the tags found

=item $cluster->register_tag($tag,@hosts);

Register the given tag name with the given host names.

=item @entries = $cluster->get_tag('tag');

Retrieve all entries for the given tag

=item @tags = $cluster->list_tags();

Return an array of all available tag names

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
