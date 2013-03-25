use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);
use File::Temp qw(tempdir);
use English '-no_match_vars';

use Readonly;

BEGIN {
    use_ok("App::ClusterSSH::Cluster") || BAIL_OUT('failed to use module');
}

my $cluster1 = App::ClusterSSH::Cluster->new();
isa_ok( $cluster1, 'App::ClusterSSH::Cluster' );

my $cluster2 = App::ClusterSSH::Cluster->new();
isa_ok( $cluster2, 'App::ClusterSSH::Cluster' );

my %expected = ( people => [ 'fred', 'jo', 'pete',  ] );

$cluster1->register_tag( 'people', @{ $expected{people} } );

my @got = $cluster2->get_tag('people');
is_deeply( \@got, \@{ $expected{people} }, 'Shared cluster object' )
    or diag explain @got;
my %got = $cluster2->dump_tags;

is_deeply( \%got, \%expected, 'Shared cluster object' ) or diag explain %got;

# should pass without issue
trap {
    $cluster1->read_cluster_file( $Bin . '/30cluster.doesnt exist' );
};
is( !$trap, '', 'coped with missing file ok' );
isa_ok( $cluster1, 'App::ClusterSSH::Cluster' );

# no point running this test as root since root cannot be blocked
# from accessing the file
if ( $EUID != 0 ) {
    my $no_read = $Bin . '/30cluster.cannot_read';
    chmod 0000, $no_read;
    trap {
        $cluster1->read_cluster_file($no_read);
    };
    chmod 0644, $no_read;
    isa_ok( $trap->die, 'App::ClusterSSH::Exception::LoadFile' );
    is( $trap->die,
        "Unable to read file $no_read: Permission denied",
        'Error on reading an existing file ok'
    );
}
else {
    pass('Cannot test for lack of read access when run as root');
}

$expected{tag1} = ['host1'];
$cluster1->read_cluster_file( $Bin . '/30cluster.file1' );
test_expected( 'file 1', %expected );

$expected{tag2} = [ 'host2', ];
$expected{tag3} = [ 'host3', 'host4' ];
$cluster1->read_cluster_file( $Bin . '/30cluster.file2' );
test_expected( 'file 2', %expected );

$expected{tag10} = [ 'host10', 'host20', 'host30' ];
$expected{tag20} = [ 'host10', ];
$expected{tag30} = [ 'host10', ];
$expected{tag40} = [ 'host20', 'host30', ];
$expected{tag50} = [ 'host30', ];
$cluster1->read_tag_file( $Bin . '/30cluster.tag1' );
test_expected( 'tag 1', %expected );

# now checks agains running an external command



done_testing();

sub test_expected {
    my ( $test, %expected ) = @_;

    foreach my $key ( keys %expected ) {
        my @got = $cluster2->get_tag($key);
        is_deeply(
            \@got,
            \@{ $expected{$key} },
            'file ' . $test . ' get_tag on: '. $key
        ) or diag explain @got;
    }

    my %got = $cluster1->dump_tags;
    is_deeply( \%got, \%expected, 'file ' . $test . ' dump_tags' )
        or diag explain %got;
}
