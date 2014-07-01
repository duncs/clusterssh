use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;

BEGIN { use_ok('App::ClusterSSH::Getopt') }

my $getopts;

$getopts = App::ClusterSSH::Getopt->new();
isa_ok( $getopts, 'App::ClusterSSH::Getopt' );

diag('testing output') if ( $ENV{TEST_VERBOSE} );


done_testing;
