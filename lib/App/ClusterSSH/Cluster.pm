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

sub list_external_clusters {
    my ( $self, ) = @_;

    my @list = $self->_run_external_clusters('-L');
    return wantarray
        ? sort @list
        : scalar @list;
}

sub get_external_clusters {
    my ( $self, @tags ) = @_;

    return $self->_run_external_clusters(@tags);
}

sub _run_external_clusters {
    my ( $self, @args ) = @_;

    my $external_command = $self->parent->config->{external_cluster_command};

    if ( !$external_command || !-x $external_command ) {
        $self->debug(
            1,
            'Cannot run external cluster command: ',
            $external_command || ''
        );
        return;
    }

    $self->debug( 3, 'Running tags through external command' );
    $self->debug( 4, 'External command: ', $external_command );
    $self->debug( 3, 'Args ', join( ',', @args ) );

    my $command = "$external_command @args";

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
                    "External command failure.\nCommand: [_1]\nReturn Code: [_2]",
                    $command,
                    $return_code,
                ),
            )
        );
    }

    my @results = split / /, $result;

    return @results;
}

sub expand_filename {
    my ( $self, $filename ) = @_;
    my $home;

    # try to determine the home directory
    if ( !defined( $home = $ENV{'HOME'} ) ) {
        $home = ( getpwuid($>) )[5];
    }
    if ( !defined($home) ) {
        $self->debug( 3, 'No home found so leaving filename ',
            $filename, ' unexpanded' );
        return $filename;
    }
    $self->debug( 4, 'Using ', $home, ' as home directory' );

    # expand ~ or $HOME
    my $new_name = $filename;
    $new_name =~ s!^~/!$home/!g;
    $new_name =~ s!^\$HOME/!$home/!g;

    $self->debug( 2, 'Expanding ', $filename, ' to ', $new_name )
        unless ( $filename eq $new_name );

    return $new_name;
}

sub read_tag_file {
    my ( $self, $filename ) = @_;

    $filename = $self->expand_filename($filename);

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

    $filename = $self->expand_filename($filename);

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

    @tags = $self->expand_glob( 'node', $node, @tags );

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

    #warn "b4 nodes=@nodes";
    @nodes = $self->expand_glob( 'tag', $tag, @nodes );

    #warn "af nodes=@nodes";

    $self->debug( 2, "Registering tag $tag: ", join( ' ', @nodes ) );

    $self->{tags}->{$tag} = \@nodes;

    return $self;
}

sub expand_glob {
    my ( $self, $type, $name, @items ) = @_;

    my @expanded;

    # skip expanding anything that appears to have nasty metachars
    if ( !grep {m/[\`\!\$;]/} @items ) {
        if ( grep {m/[{]/} @items ) {

      #@expanded = split / /, `/bin/bash -c 'shopt -s extglob\n echo @items'`;
            my $cmd = $self->parent->config->{shell_expansion};
            $cmd =~ s/%items%/@items/;
            @expanded = split / /, `$cmd`;
            chomp(@expanded);
        }
        else {
            @expanded = map { glob $_ } @items;
        }
    }
    else {
        warn(
            $self->loc(
                "Bad characters picked up in [_1] '[_2]': [_3]",
                $type, $name, join( ' ', @items )
            ),
        );
    }

    return @expanded;
}

sub get_tag {
    my ( $self, $tag ) = @_;

    if ( $self->{tags}->{$tag} ) {
        $self->debug(
            2,
            "Retrieving tag $tag: ",
            join( ' ', sort @{ $self->{tags}->{$tag} } )
        );

        return wantarray
            ? sort @{ $self->{tags}->{$tag} }
            : scalar @{ $self->{tags}->{$tag} };
    }

    $self->debug( 2, "Tag $tag is not registered" );
    return;
}

sub list_tags {
    my ($self) = @_;
    return wantarray
        ? sort keys( %{ $self->{tags} } )
        : scalar keys( %{ $self->{tags} } );
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

=item @external_tags=list_external_clusters()

Call an external script suing C<-L> to list available tags

=item @resolved_tags=get_external_clusters(@tags)

Use an external script to resolve C<@tags> into hostnames.

=item $cluster->get_tag_entries($filename);

Read in /etc/tags, $HOME/.clusterssh/tags and any other given 
file name and register the tags found.

=item $cluster->read_cluster_file($filename);

Read in the given cluster file and register the tags found

=item $cluster->expand_filename($filename);

Expand ~ or $HOME in a filename

=item $cluster->read_tag_file($filename);

Read in the given tag file and register the tags found

=item $cluster->register_tag($tag,@hosts);

Register the given tag name with the given host names.

=item $cluster->register_host($host,@tags);

Register the given host on the provided tags.

=item @entries = $cluster->get_tag('tag');

=item $entries = $cluster->get_tag('tag');

Retrieve all entries for the given tag.  Returns an array of hosts or 
the number of hosts in the array depending on context.

=item @tags = $cluster->list_tags();

Return an array of all available tag names

=item %tags = $cluster->dump_tags();

Returns a hash of all tag data.

=item @tags = $cluster->expand_glob( $type, $name, @items );

Use shell expansion against each item in @items, where $type is either 'node', or 'tag' and $name is the node or tag name.  These attributes are presented to the user in the event of an issue with the expanion to track down the source.

=back

=head1 AUTHOR

Duncan Ferguson, C<< <duncan_j_ferguson at yahoo.co.uk> >>

=head1 LICENSE AND COPYRIGHT

Copyright 1999-2015 Duncan Ferguson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
