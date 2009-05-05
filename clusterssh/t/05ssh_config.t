use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

#use Test::More tests => 16;
use Test::More qw/ no_plan /;
use Test::Trap;

#plan tests => 5;
#plan qw(no_plan);

BEGIN { use_ok("ClusterSSH::Config::SSH") }

my $config;
my $test_file;

$config = ClusterSSH::Config::SSH->new();
isa_ok( $config, 'ClusterSSH::Config::SSH' );
is( $config->get_filename, $ENV{HOME} . '/.ssh/config', 'filename set ok' );
$config = undef;
is( $config, undef, 'config destroyed OK' );

$test_file = "$Bin/${Script}_doesnt_exist";
trap {
    $config = ClusterSSH::Config::SSH->new( { filename => $test_file } );
};
is( $trap->leaveby, 'die', 'died ok' );
like( $trap->die, qr/^File .* does not exist./, 'not died' );
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Expecting no STDOUT' );

$test_file = "$Bin/${Script}_ssh_config";
trap {
    $config = ClusterSSH::Config::SSH->new( { filename => $test_file } );
};
is( $trap->leaveby, 'return', 'died ok' );
is( $trap->die,     undef,    'not died' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
isa_ok( $config, 'ClusterSSH::Config::SSH' );
is( $config->get_filename, $test_file, 'filename set ok' );

is( $config->is_valid_hostname('testing'), 0, 'Checking unknown ok' );
is( $config->is_valid_hostname('server1'), 1, 'Checking server1 ok' );
is( $config->is_valid_hostname('server2'), 1, 'Checking server2 ok' );
is( $config->is_valid_hostname('server3'), 1, 'Checking server3 ok' );
is( $config->is_valid_hostname('server4'), 1, 'Checking server4 ok' );
is( $config->is_valid_hostname('server5'), 1, 'Checking server5 ok' );
is( $config->is_valid_hostname('server6'), 1, 'Checking server6 ok' );
