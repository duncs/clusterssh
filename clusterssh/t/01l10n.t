use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 2;
use Test::Trap;

BEGIN { use_ok( "ClusterSSH::L10N", ) }

my $handle;

$handle = ClusterSSH::L10N->get_handle();
isa_ok( $handle, 'ClusterSSH::L10N' );
