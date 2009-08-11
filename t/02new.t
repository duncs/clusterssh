use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 3;

BEGIN { use_ok("ClusterSSH") }

like( $ClusterSSH::VERSION, qr/3.\d{2}_\d{1,2}/, 'VERSION ok' );

my $cssh = ClusterSSH->new();
isa_ok( $cssh, "ClusterSSH" );
