use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;

BEGIN { use_ok( 'App::ClusterSSH::Gui' ) }

# force default language for tests
App::ClusterSSH::Gui->set_lang('en');

my $gui;

$gui = App::ClusterSSH::Gui->new();
isa_ok( $gui, 'App::ClusterSSH::Gui' );

done_testing();
