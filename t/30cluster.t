use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);
use File::Temp qw(tempdir);

use Readonly;

BEGIN {
    use_ok("App::ClusterSSH::Cluster") || BAIL_OUT('failed to use module');
}

my $cluster1 = App::ClusterSSH::Cluster->new();
isa_ok( $cluster1, 'App::ClusterSSH::Cluster' );

my $cluster2 = App::ClusterSSH::Cluster->new();
isa_ok( $cluster2, 'App::ClusterSSH::Cluster' );

my @expected = ( 'pete', 'jo', 'fred' );

$cluster1->register_tag( 'people', @expected );

my @got = $cluster2->get_tag('people');

is_deeply( \@got, \@expected,
    'Shared cluster object' );

# should pass without issue
trap {
    $cluster1->read_cluster_file( $Bin . '/30cluster.doesnt exist' );
};
is( ! $trap, '', 'coped with missing file ok' );
isa_ok( $cluster1, 'App::ClusterSSH::Cluster' );

my $no_read=$Bin . '/30cluster.cannot_read';
chmod 0000, $no_read;
trap {
    $cluster1->read_cluster_file( $no_read );
};
chmod 0644, $no_read;
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Cluster' );
is( $trap->die, "Unable to read file $no_read: Permission denied", 'Error on reading an existing file ok');

@expected = ('host1');
$cluster1->read_cluster_file( $Bin . '/30cluster.file1' );
@got = $cluster1->get_tag('tag1');
is_deeply( \@got, \@expected, 'read simple file OK' );

@expected = ('host1');
$cluster1->read_cluster_file( $Bin . '/30cluster.file2' );
@got=$cluster1->get_tag('tag1');
is_deeply( \@got,
    \@expected, 'read more complex file OK' );

@expected = ('host2');
@got=$cluster1->get_tag('tag2');
is_deeply( \@got,
    \@expected, 'read more complex file OK' );

@expected = ( 'host3', 'host4' );
@got=$cluster1->get_tag('tag3');
is_deeply( \@got,
    \@expected, 'read more complex file OK' );

done_testing();
