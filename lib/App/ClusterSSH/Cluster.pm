package App::ClusterSSH::Cluster;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;
use Try::Tiny;
use English qw( -no_match_vars );

use base qw/ App::ClusterSSH::Base /;

our $master_object_ref;

sub new {
    my ( $class, %args ) = @_;

    if ( !$master_object_ref ) {
        $master_object_ref = $class->SUPER::new(%args);
    }

    return $master_object_ref;
}

sub get_cluster_entries {
    my ( $self, @files ) = @_;

    for my $file ( '/etc/clusters', $ENV{HOME} . '/.clusterssh/clusters',
        @files )
    {
        $self->debug( 3, 'Loading in clusters from: ', $file );
        $self->read_cluster_file($file);
    }

    return $self;
}

sub get_tag_entries {
    my ( $self, @files ) = @_;

    for my $file ( '/etc/tags', $ENV{HOME} . '/.clusterssh/tags', @files ) {
        $self->debug( 3, 'Loading in tags from: ', $file );
        $self->read_tag_file($file);
    }

    return $self;
}

sub get_external_clusters {
    my ( $self, $external_command, @tags ) = @_;

    $self->debug( 3, 'Running tags through external command' );
    $self->debug( 4, 'External command: ', $external_command );
    $self->debug( 3, 'Tags: ', join( ',', @tags ) );

    my $command = "$external_command @tags";

    $self->debug( 3, 'Running ', $command );

    my $result;
    my $return_code;
    {
        local $SIG{CHLD} = undef;
        $result      = qx/ $command /;
        $return_code = $CHILD_ERROR >> 8;
    }
    chomp($result);

    $self->debug( 3, "Result: $result" );
    $self->debug( 3, "Return code: $return_code" );

    if ( $return_code != 0 ) {
        croak(
            App::ClusterSSH::Exception::Cluster->throw(
                error => $self->loc(
                    "External command exited failed.\nCommand: [_1]\nReturn Code: [_2]",
                    $command,
                    $return_code,
                ),
            )
        );
    }

    my @results = split / /, $result;

    return @results;
}

sub read_tag_file {
    my ( $self, $filename ) = @_;
    $self->debug( 2, 'Reading tags from file ', $filename );
    if ( -f $filename ) {
        my %hosts
            = $self->load_file( type => 'cluster', filename => $filename );
        foreach my $host ( keys %hosts ) {
            $self->debug( 4, "Got entry for $host on tags $hosts{$host}" );
            $self->register_host( $host, split( /\s+/, $hosts{$host} ) );
        }
    }
    else {
        $self->debug( 2, 'No file found to read' );
    }
    return $self;
}

sub read_cluster_file {
    my ( $self, $filename ) = @_;
    $self->debug( 2, 'Reading clusters from file ', $filename );

    if ( -f $filename ) {
        my %tags
            = $self->load_file( type => 'cluster', filename => $filename );

        foreach my $tag ( keys %tags ) {
            $self->register_tag( $tag, split( /\s+/, $tags{$tag} ) );
        }
    }
    else {
        $self->debug( 2, 'No file found to read' );
    }
    return $self;
}

sub register_host {
    my ( $self, $node, @tags ) = @_;
    $self->debug( 2, "Registering node $node on tags:", join( ' ', @tags ) );

    foreach my $tag (@tags) {
        if ( $self->{tags}->{$tag} ) {
            $self->{tags}->{$tag}
                = [ sort @{ $self->{tags}->{$tag} }, $node ];
        }
        else {
            $self->{tags}->{$tag} = [$node];
        }

        #push(@{ $self->{tags}->{$tag} }, $node);
    }
    return $self;
}

sub register_tag {
    my ( $self, $tag, @nodes ) = @_;

    $self->debug( 2, "Registering tag $tag: ", join( ' ', @nodes ) );

    $self->{tags}->{$tag} = \@nodes;

    return $self;
}

sub get_tag {
    my ( $self, $tag ) = @_;

    if ( $self->{tags}->{$tag} ) {
        $self->debug(
            2,
            "Retrieving tag $tag: ",
            join( ' ', sort @{ $self->{tags}->{$tag} } )
        );

        return sort @{ $self->{tags}->{$tag} };
    }

    $self->debug( 2, "Tag $tag is not registered" );
    return;
}

sub list_tags {
    my ($self) = @_;
    return sort keys( %{ $self->{tags} } );
}

sub dump_tags {
    my ($self) = @_;
    return %{ $self->{tags} };
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

=item $cluster->get_cluster_entries($filename);

Read in /etc/clusters, $HOME/.clusterssh/clusters and any other given 
file name and register the tags found.

=item $cluster->get_tag_entries($filename);

Read in /etc/tags, $HOME/.clusterssh/tags and any other given 
file name and register the tags found.

=item $cluster->read_cluster_file($filename);

Read in the given cluster file and register the tags found

=item $cluster->read_tag_file($filename);

Read in the given tag file and register the tags found

=item $cluster->register_tag($tag,@hosts);

Register the given tag name with the given host names.

=item $cluster->register_host($host,@tags);

Register the given host on the provided tags.

=item @entries = $cluster->get_tag('tag');

Retrieve all entries for the given tag

=item @tags = $cluster->list_tags();

Return an array of all available tag names

=item %tags = $cluster->dump_tags();

Returns a hash of all tag data.

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
