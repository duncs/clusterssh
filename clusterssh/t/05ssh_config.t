use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 16;

#plan tests => 5;
#plan qw(no_plan);

BEGIN { use_ok("ClusterSSH::Config::SSH") }

my $config;

$config = ClusterSSH::Config::SSH->new();
isa_ok( $config, 'ClusterSSH::Config::SSH' );
is( $config->get_filename, $ENV{HOME} . '/.ssh/config', 'filename set ok' );

$config
    = ClusterSSH::Config::SSH->new( { filename => $Bin . '/doesnt_exist' } );
isa_ok( $config, 'ClusterSSH::Config::SSH' );
is( $config->get_filename, $Bin . '/doesnt_exist', 'filename set ok' );

is( $config->is_valid_hostname('testing'), 0, 'Checking unknown ok' );
is( $config->is_valid_hostname('server1'), 0, 'Checking unknown ok' );

$config
    = ClusterSSH::Config::SSH->new( { filename => $Bin . '/ssh_config' } );
isa_ok( $config, 'ClusterSSH::Config::SSH' );
is( $config->get_filename, $Bin . '/ssh_config', 'filename set ok' );

is( $config->is_valid_hostname('testing'), 0, 'Checking unknown ok' );
is( $config->is_valid_hostname('server1'), 1, 'Checking server1 ok' );
is( $config->is_valid_hostname('server2'), 1, 'Checking server2 ok' );
is( $config->is_valid_hostname('server3'), 1, 'Checking server3 ok' );
is( $config->is_valid_hostname('server4'), 1, 'Checking server4 ok' );
is( $config->is_valid_hostname('server5'), 1, 'Checking server5 ok' );
is( $config->is_valid_hostname('server6'), 1, 'Checking server6 ok' );
