use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);
use File::Temp qw(tempdir);

use Readonly;

BEGIN { use_ok("App::ClusterSSH::Helper")  || BAIL_OUT('failed to use module')}

my $helper;

$helper = App::ClusterSSH::Helper->new();
isa_ok( $helper, 'App::ClusterSSH::Helper' );

#note('check failure to write default config is caught');
#$ENV{HOME} = tempdir( CLEANUP => 1 );
#mkdir($ENV{HOME}.'/.clusterssh');
#mkdir($ENV{HOME}.'/.clusterssh/config');
#$config = App::ClusterSSH::Config->new();
#trap {
#    $config->load_configs();
#};
#is( $trap->leaveby, 'return', 'returned ok' );
#isa_ok( $config,    "App::ClusterSSH::Config" );
#isa_ok( $config, "App::ClusterSSH::Config" );
#is( $trap->stdout, q{}, 'Expecting no STDOUT' );
#is( $trap->stderr, q{Unable to write default $HOME/.clusterssh/config: Is a directory}.$/, 'Expecting no STDERR' );

done_testing();
