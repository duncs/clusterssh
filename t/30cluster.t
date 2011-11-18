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

$cluster1->{cluster} = 'fred';

ok( defined( $cluster2->{cluster} ), 'Shared cluster object' );

done_testing();
