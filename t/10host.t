use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;

BEGIN { use_ok("App::ClusterSSH::Host") }

my $host;

eval { $host = App::ClusterSSH::Host->new(); };
like( $@, qr/hostname is undefined/, 'eval error - hostname is undefined (method)' );

diag('Checking IPv4 type addresses') if ( $ENV{TEST_VERBOSE} );
$host = App::ClusterSSH::Host->new( hostname => 'hostname' );
is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'hostname set' );
is( $host->get_port,     undef,      'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host->set_port(2323);

is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host->set_username('username');

is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new( hostname => 'hostname' );
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'hostname set' );
is( $host->get_port,     undef,      'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host->set_port(2323);

is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host->set_username('username');

is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new(
    hostname => 'hostname',
    port     => 2323,
);
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'hostname set' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host->set_username('username');

is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new(
    hostname => 'hostname',
    username => 'username',
);
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'hostname set' );
is( $host->get_port,     undef,      'checking set works' );
is( $host->get_username, 'username', 'username is set' );

$host->set_port(2323);

is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new(
    hostname => 'hostname',
    username => 'username',
    port     => 2323,

);
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is set' );

$host = undef;
is( $host, undef, 'starting afresh' );

diag('Parsing IPv4 hostname') if ( $ENV{TEST_VERBOSE} );

$host = App::ClusterSSH::Host->parse_host_string('hostname');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     undef,      'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host = App::ClusterSSH::Host->parse_host_string('host%name');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'host%name', 'stringify works' );
is( $host->get_hostname, 'host%name', 'checking set works' );
is( $host->get_port,     undef,      'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('hostname:2323');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host = App::ClusterSSH::Host->parse_host_string('host%name:2323');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'host%name', 'stringify works' );
is( $host->get_hostname, 'host%name', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, undef,      'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('username@hostname:2323');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is set' );

$host = App::ClusterSSH::Host->parse_host_string('username@host%name:2323');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'host%name', 'stringify works' );
is( $host->get_hostname, 'host%name', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('username@hostname');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'hostname', 'stringify works' );
is( $host->get_hostname, 'hostname', 'checking set works' );
is( $host->get_port,     undef,      'checking set works' );
is( $host->get_username, 'username', 'username is set' );

$host = App::ClusterSSH::Host->parse_host_string('username@host%name');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               'host%name', 'stringify works' );
is( $host->get_hostname, 'host%name', 'checking set works' );
is( $host->get_port,     undef,      'checking set works' );
is( $host->get_username, 'username', 'username is set' );

diag('Parsing IPv4 IP address') if ( $ENV{TEST_VERBOSE} );

$host = App::ClusterSSH::Host->parse_host_string('127.0.0.1');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '127.0.0.1', 'stringify works' );
is( $host->get_hostname, '127.0.0.1', 'checking set works' );
is( $host->get_port,     undef,       'checking set works' );
is( $host->get_username, undef,       'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('127.0.0.1:2323');
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               '127.0.0.1', 'stringify works' );
is( $host->get_hostname, '127.0.0.1', 'checking set works' );
is( $host->get_port,     2323,        'checking set works' );
is( $host->get_username, undef,       'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('username@127.0.0.1:2323');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '127.0.0.1', 'stringify works' );
is( $host->get_hostname, '127.0.0.1', 'checking set works' );
is( $host->get_port,     2323,        'checking set works' );
is( $host->get_username, 'username',  'username is set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('username@127.0.0.1');
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               '127.0.0.1', 'stringify works' );
is( $host->get_hostname, '127.0.0.1', 'checking set works' );
is( $host->get_port,     undef,       'checking set works' );
is( $host->get_username, 'username',  'username is set' );

diag('Checking IPv6 type addresses') if ( $ENV{TEST_VERBOSE} );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('::1');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '::1', 'stringify works' );
is( $host->get_hostname, '::1', 'checking set works' );
is( $host->get_port,     undef, 'port is undef' );
is( $host->get_username, undef, 'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('username@::1');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '::1',      'stringify works' );
is( $host->get_hostname, '::1',      'checking set works' );
is( $host->get_port,     undef,      'port is undef' );
is( $host->get_username, 'username', 'username is set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('[::1]');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '::1', 'stringify works' );
is( $host->get_hostname, '::1', 'checking set works' );
is( $host->get_port,     undef, 'port is undef' );
is( $host->get_username, undef, 'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('username@[::1]');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '::1',      'stringify works' );
is( $host->get_hostname, '::1',      'checking set works' );
is( $host->get_port,     undef,      'port is undef' );
is( $host->get_username, 'username', 'username is set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('[::1]:22');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '::1', 'stringify works' );
is( $host->get_hostname, '::1', 'checking set works' );
is( $host->get_port,     22,    'checking port set' );
is( $host->get_username, undef, 'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('username@[::1]:22');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '::1',      'stringify works' );
is( $host->get_hostname, '::1',      'checking set works' );
is( $host->get_port,     22,         'checking port set' );
is( $host->get_username, 'username', 'username is set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->parse_host_string('2001:0db8:85a3:0000:0000:8a2e:0370:7334');
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host,               '2001:0db8:85a3:0000:0000:8a2e:0370:7334', 'stringify works' );
is( $host->get_hostname, '2001:0db8:85a3:0000:0000:8a2e:0370:7334', 'checking set works' );
is( $host->get_port,     undef,                                     'port is undef' );
is( $host->get_username, undef,                                     'username is undef' );

$host = undef;
is( $host, undef, 'starting afresh' );

trap {
    $host = App::ClusterSSH::Host->parse_host_string('2001:0db8:85a3::8a2e:0370:7334');
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host, '2001:0db8:85a3::8a2e:0370:7334', 'stringify works' );

is( $trap->stdout, '', 'Expecting no STDOUT' );
is( $trap->stderr =~ tr/\n//, 2, 'got correct number of print lines' );
like( $trap->stderr, qr/^Ambiguous host string: "2001:0db8:85a3::8a2e:0370:7334/,  'checking warning output' );
like( $trap->stderr, qr/Assuming you meant "\[2001:0db8:85a3::8a2e:0370:7334\]"?/, 'checking warning output' );

is( $host->get_hostname, '2001:0db8:85a3::8a2e:0370:7334', 'checking set works' );
is( $host->get_port,     undef,                            'port is undef' );
is( $host->get_username, undef,                            'username is undef' );

done_testing();
