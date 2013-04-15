use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);

use Readonly;

BEGIN { use_ok("App::ClusterSSH") }

my $app;

$app = App::ClusterSSH->new();
isa_ok( $app,         'App::ClusterSSH' );
isa_ok( $app->config, 'App::ClusterSSH::Config' );

done_testing();
