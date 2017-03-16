use strict;
use warnings;

# Force use of English in tests for the moment, for those users that
# have a different locale set, since errors are hardcoded below
use POSIX qw(setlocale locale_h);
setlocale( LC_ALL, "C" );

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;

BEGIN { use_ok("App::ClusterSSH::Host") }

my $host;

eval { $host = App::ClusterSSH::Host->new(); };
isa_ok( $@, 'App::ClusterSSH::Exception', 'Caught exception object OK' );
like(
    $@,
    qr/hostname is undefined/,
    'eval error - hostname is undefined (method)'
);

#=============
# NOTE:
#=============
# 'Eevo5ang' is a randomly generated hostname used in these tests
# as one user actually had a host called 'hostname' on their network
# 'Ooquiida.com' is also a randomly generated domain name

diag('Checking IPv4 type addresses') if ( $ENV{TEST_VERBOSE} );
$host = App::ClusterSSH::Host->new( hostname => 'Eevo5ang' );
is( $host,               'Eevo5ang', 'stringify works' );
is( $host->get_hostname, 'Eevo5ang', 'hostname set' );
is( $host->get_port,     q{},        'checking set works' );
is( $host->get_username, q{},        'username is unset' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );
is( $host->get_master,   q{},        'master set' );
is( $host->get_type,     q{},        'type set' );

$host->set_port(2323);

is( $host,               'Eevo5ang', 'stringify works' );
is( $host->get_hostname, 'Eevo5ang', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, q{},        'username is unset' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );
is( $host->get_master,   q{},        'master set' );
is( $host->get_type,     q{},        'type set' );

$host->set_username('username');

is( $host->get_hostname, 'Eevo5ang', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is unset' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );
is( $host->get_master,   q{},        'master set' );
is( $host->get_type,     q{},        'type set' );

$host->set_geometry('100x50+100+100');

is( $host->get_hostname, 'Eevo5ang',       'checking set works' );
is( $host->get_port,     2323,             'checking set works' );
is( $host->get_username, 'username',       'username is unset' );
is( $host->get_realname, 'Eevo5ang',       'realname set' );
is( $host->get_geometry, '100x50+100+100', 'geometry set' );
is( $host->get_master,   q{},              'master set' );
is( $host->get_type,     q{},              'type set' );

$host->set_master('some_host');

is( $host->get_hostname, 'Eevo5ang',       'checking set works' );
is( $host->get_port,     2323,             'checking set works' );
is( $host->get_username, 'username',       'username is unset' );
is( $host->get_realname, 'Eevo5ang',       'realname set' );
is( $host->get_geometry, '100x50+100+100', 'geometry set' );
is( $host->get_master,   'some_host',      'master set' );
is( $host->get_type,     q{},              'type set' );

$host->set_type('something');

is( $host->get_hostname, 'Eevo5ang',       'checking set works' );
is( $host->get_port,     2323,             'checking set works' );
is( $host->get_username, 'username',       'username is unset' );
is( $host->get_realname, 'Eevo5ang',       'realname set' );
is( $host->get_geometry, '100x50+100+100', 'geometry set' );
is( $host->get_master,   'some_host',      'master set' );
is( $host->get_type,     'something',      'type set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new(
    hostname => 'Eevo5ang',
    port     => 2323,
);
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'Eevo5ang', 'stringify works' );
is( $host->get_hostname, 'Eevo5ang', 'hostname set' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, q{},        'username is unset' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );

$host->set_username('username');

is( $host->get_hostname, 'Eevo5ang', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is unset' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new(
    hostname => 'Eevo5ang',
    username => 'username',
);
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'Eevo5ang', 'stringify works' );
is( $host->get_hostname, 'Eevo5ang', 'hostname set' );
is( $host->get_port,     q{},        'checking set works' );
is( $host->get_username, 'username', 'username is set' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );

$host->set_port(2323);

is( $host->get_hostname, 'Eevo5ang', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is set' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new(
    hostname => 'Eevo5ang',
    username => 'username',
    port     => 2323,

);
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'Eevo5ang', 'stringify works' );
is( $host->get_hostname, 'Eevo5ang', 'checking set works' );
is( $host->get_port,     2323,       'checking set works' );
is( $host->get_username, 'username', 'username is set' );
is( $host->get_realname, 'Eevo5ang', 'realname set' );
is( $host->get_geometry, q{},        'geometry set' );

$host = undef;
is( $host, undef, 'starting afresh' );

$host = App::ClusterSSH::Host->new(
    hostname => 'Eevo5ang',
    username => 'username',
    port     => 2323,
    geometry => '100x50+100+100',
);
isa_ok( $host, "App::ClusterSSH::Host" );

is( $host,               'Eevo5ang',       'stringify works' );
is( $host->get_hostname, 'Eevo5ang',       'checking set works' );
is( $host->get_port,     2323,             'checking set works' );
is( $host->get_username, 'username',       'username is set' );
is( $host->get_realname, 'Eevo5ang',       'realname set' );
is( $host->get_geometry, '100x50+100+100', 'geometry set' );

diag('Parsing tests') if ( $ENV{TEST_VERBOSE} );

my %parse_tests = (
    'Eevo5ang' => {
        hostname => 'Eevo5ang',
        port     => q{},
        username => q{},
        realname => 'Eevo5ang',
        geometry => q{},
        type     => 'ipv4',
    },
    'Eevo5ang.Ooquiida.com' => {
        hostname => 'Eevo5ang.Ooquiida.com',
        port     => q{},
        username => q{},
        realname => 'Eevo5ang.Ooquiida.com',
        geometry => q{},
        type     => 'ipv4',
    },
    'Eevo5ang:2323' => {
        hostname => 'Eevo5ang',
        port     => 2323,
        username => q{},
        realname => 'Eevo5ang',
        geometry => q{},
        type     => 'ipv4',
    },
    'Eevo5ang:3232=1x1+1+1' => {
        hostname => 'Eevo5ang',
        port     => 3232,
        username => q{},
        realname => 'Eevo5ang',
        geometry => '1x1+1+1',
        type     => 'ipv4',
    },
    'Eevo5ang.Ooquiida.com:3232' => {
        hostname => 'Eevo5ang.Ooquiida.com',
        port     => 3232,
        username => q{},
        realname => 'Eevo5ang.Ooquiida.com',
        geometry => q{},
        type     => 'ipv4',
    },
    'Eevo5ang.Ooquiida.com:3232=1x1+1+1' => {
        hostname => 'Eevo5ang.Ooquiida.com',
        port     => 3232,
        username => q{},
        realname => 'Eevo5ang.Ooquiida.com',
        geometry => '1x1+1+1',
        type     => 'ipv4',
    },
    'user@Eevo5ang' => {
        hostname => 'Eevo5ang',
        port     => q{},
        username => 'user',
        realname => 'Eevo5ang',
        geometry => q{},
        type     => 'ipv4',
    },
    'user@Eevo5ang.Ooquiida.com' => {
        hostname => 'Eevo5ang.Ooquiida.com',
        port     => q{},
        username => 'user',
        realname => 'Eevo5ang.Ooquiida.com',
        geometry => q{},
        type     => 'ipv4',
    },
    'user@Eevo5ang:2323' => {
        hostname => 'Eevo5ang',
        port     => 2323,
        username => 'user',
        realname => 'Eevo5ang',
        geometry => q{},
        type     => 'ipv4',
    },
    'user@Eevo5ang:3232=1x1+1+1' => {
        hostname => 'Eevo5ang',
        port     => 3232,
        username => 'user',
        realname => 'Eevo5ang',
        geometry => '1x1+1+1',
        type     => 'ipv4',
    },
    'user@Eevo5ang.Ooquiida.com:3232' => {
        hostname => 'Eevo5ang.Ooquiida.com',
        port     => 3232,
        username => 'user',
        realname => 'Eevo5ang.Ooquiida.com',
        geometry => q{},
        type     => 'ipv4',
    },
    'user@Eevo5ang.Ooquiida.com:3232=1x1+1+1' => {
        hostname => 'Eevo5ang.Ooquiida.com',
        port     => 3232,
        username => 'user',
        realname => 'Eevo5ang.Ooquiida.com',
        geometry => '1x1+1+1',
        type     => 'ipv4',
    },
    '127.0.0.1' => {
        hostname => '127.0.0.1',
        port     => q{},
        username => q{},
        realname => '127.0.0.1',
        geometry => q{},
        type     => 'ipv4',
    },
    '127.0.0.1:2323' => {
        hostname => '127.0.0.1',
        port     => 2323,
        username => q{},
        realname => '127.0.0.1',
        geometry => q{},
        type     => 'ipv4',
    },
    '127.0.0.1:3232=1x1+1+1' => {
        hostname => '127.0.0.1',
        port     => 3232,
        username => q{},
        realname => '127.0.0.1',
        geometry => '1x1+1+1',
        type     => 'ipv4',
    },
    'user@127.0.0.1' => {
        hostname => '127.0.0.1',
        port     => q{},
        username => 'user',
        realname => '127.0.0.1',
        geometry => q{},
        type     => 'ipv4',
    },
    'user@127.0.0.1:2323' => {
        hostname => '127.0.0.1',
        port     => 2323,
        username => 'user',
        realname => '127.0.0.1',
        geometry => q{},
        type     => 'ipv4',
    },
    'user@127.0.0.1=2x2+2+2' => {
        hostname => '127.0.0.1',
        port     => q{},
        username => 'user',
        realname => '127.0.0.1',
        geometry => '2x2+2+2',
        type     => 'ipv4',
    },
    'user@127.0.0.1:3232=1x1+1+1' => {
        hostname => '127.0.0.1',
        port     => 3232,
        username => 'user',
        realname => '127.0.0.1',
        geometry => '1x1+1+1',
        type     => 'ipv4',
    },
    '::1' => {
        hostname => '::1',
        port     => q{},
        username => q{},
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    '::1:2323' => {
        hostname => '::1:2323',
        port     => q{},
        username => q{},
        realname => '::1:2323',
        geometry => q{},
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    '::1/2323' => {
        hostname => '::1',
        port     => 2323,
        username => q{},
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    '::1:2323=3x3+3+3' => {
        hostname => '::1:2323',
        port     => q{},
        username => q{},
        realname => '::1:2323',
        geometry => '3x3+3+3',
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    '::1/2323=3x3+3+3' => {
        hostname => '::1',
        port     => 2323,
        username => q{},
        realname => '::1',
        geometry => '3x3+3+3',
        type     => 'ipv6',
    },
    'user@::1' => {
        hostname => '::1',
        port     => q{},
        username => 'user',
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    'user@::1:4242' => {
        hostname => '::1:4242',
        port     => q{},
        username => 'user',
        realname => '::1:4242',
        geometry => q{},
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    'user@::1/4242' => {
        hostname => '::1',
        port     => 4242,
        username => 'user',
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    'user@::1=5x5+5+5' => {
        hostname => '::1',
        port     => q{},
        username => 'user',
        realname => '::1',
        geometry => '5x5+5+5',
        type     => 'ipv6',
    },
    'user@::1:4242=5x5+5+5' => {
        hostname => '::1:4242',
        port     => q{},
        username => 'user',
        realname => '::1:4242',
        geometry => '5x5+5+5',
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    'user@::1/4242=5x5+5+5' => {
        hostname => '::1',
        port     => 4242,
        username => 'user',
        realname => '::1',
        geometry => '5x5+5+5',
        type     => 'ipv6',
    },
    '[::1]' => {
        hostname => '::1',
        port     => q{},
        username => q{},
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    '[::1]:2323' => {
        hostname => '::1',
        port     => 2323,
        username => q{},
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    '[::1]:2323=3x3+3+3' => {
        hostname => '::1',
        port     => 2323,
        username => q{},
        realname => '::1',
        geometry => '3x3+3+3',
        type     => 'ipv6',
    },
    'user@[::1]' => {
        hostname => '::1',
        port     => q{},
        username => 'user',
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    'user@[::1]:4242' => {
        hostname => '::1',
        port     => 4242,
        username => 'user',
        realname => '::1',
        geometry => q{},
        type     => 'ipv6',
    },
    'user@[::1]=5x5+5+5' => {
        hostname => '::1',
        port     => q{},
        username => 'user',
        realname => '::1',
        geometry => '5x5+5+5',
        type     => 'ipv6',
    },
    'user@[::1]:4242=5x5+5+5' => {
        hostname => '::1',
        port     => 4242,
        username => 'user',
        realname => '::1',
        geometry => '5x5+5+5',
        type     => 'ipv6',
    },
    '2001:0db8:85a3:0000:0000:8a2e:0370:7334' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    'jo@2001:0db8:85a3:0000:0000:8a2e:0370:7334' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => 'jo',
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    '2001:0db8:85a3:0000:0000:8a2e:0370:7334=9x9+9+9' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => '9x9+9+9',
        type     => 'ipv6',
    },
    'jo@2001:0db8:85a3:0000:0000:8a2e:0370:7334=8x8+8+8' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => 'jo',
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => '8x8+8+8',
        type     => 'ipv6',
    },
    '2001:0db8:85a3:0000:0000:8a2e:0370:7334:22' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => 22,
        username => q{},
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    '2001:0db8:85a3:0000:0000:8a2e:0370:7334/22' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => 22,
        username => q{},
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    'jo@[2001:0db8:85a3:0000:0000:8a2e:0370:7334]' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => 'jo',
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]=9x9+9+9' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => '9x9+9+9',
        type     => 'ipv6',
    },
    'jo@[2001:0db8:85a3:0000:0000:8a2e:0370:7334]=8x8+8+8' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => q{},
        username => 'jo',
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => '8x8+8+8',
        type     => 'ipv6',
    },
    '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:22' => {
        hostname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        port     => 22,
        username => q{},
        realname => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    '2001:0db8:85a3::8a2e:0370:7334' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    '2001:0db8:85a3::8a2e:0370/7334' => {
        hostname => '2001:0db8:85a3::8a2e:0370',
        port     => 7334,
        username => q{},
        realname => '2001:0db8:85a3::8a2e:0370',
        geometry => q{},
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    'pete@2001:0db8:85a3::8a2e:0370:7334' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => 'pete',
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    'pete@2001:0db8:85a3::8a2e:0370/7334' => {
        hostname => '2001:0db8:85a3::8a2e:0370',
        port     => 7334,
        username => 'pete',
        realname => '2001:0db8:85a3::8a2e:0370',
        geometry => q{},
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    'pete@2001:0db8:85a3::8a2e:0370:7334=2x3+4+5' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => 'pete',
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => '2x3+4+5',
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    'pete@2001:0db8:85a3::8a2e:0370/7334=2x3+4+5' => {
        hostname => '2001:0db8:85a3::8a2e:0370',
        port     => 7334,
        username => 'pete',
        realname => '2001:0db8:85a3::8a2e:0370',
        geometry => '2x3+4+5',
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    '2001:0db8:85a3::8a2e:0370:7334=2x3+4+5' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => '2x3+4+5',
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    '2001:0db8:85a3::8a2e:0370/7334=2x3+4+5' => {
        hostname => '2001:0db8:85a3::8a2e:0370',
        port     => 7334,
        username => q{},
        realname => '2001:0db8:85a3::8a2e:0370',
        geometry => '2x3+4+5',
        type     => 'ipv6',
        stderr   => qr{Ambiguous host string:.*Assuming you meant}ms
    },
    '[2001:0db8:85a3::8a2e:0370:7334]' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    'pete@[2001:0db8:85a3::8a2e:0370:7334]' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => 'pete',
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    'pete@[2001:0db8:85a3::8a2e:0370:7334]=2x3+4+5' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => 'pete',
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => '2x3+4+5',
        type     => 'ipv6',
    },
    '[2001:0db8:85a3::8a2e:0370:7334]=2x3+4+5' => {
        hostname => '2001:0db8:85a3::8a2e:0370:7334',
        port     => q{},
        username => q{},
        realname => '2001:0db8:85a3::8a2e:0370:7334',
        geometry => '2x3+4+5',
        type     => 'ipv6',
    },
    'pete@[2001:0db8:8a2e:0370:7334]' => {
        hostname => '2001:0db8:8a2e:0370:7334',
        port     => q{},
        username => 'pete',
        realname => '2001:0db8:8a2e:0370:7334',
        geometry => q{},
        type     => 'ipv6',
    },
    '2001:0db8:8a2e:0370:7334:2001:0db8:8a2e:0370:7334:4535:3453:3453:3455'
        => { die => qr{Unable to parse hostname from}ms, },
    'some random rubbish' => { die => qr{Unable to parse hostname from}ms, },
);

foreach my $ident ( keys(%parse_tests) ) {
    $host = undef;
    trap {
        $host = App::ClusterSSH::Host->parse_host_string($ident);
    };

    if ( $parse_tests{$ident}{die} ) {
        is( $trap->leaveby, 'die', $ident . ' died correctly' );
        like(
            $trap->die,
            $parse_tests{$ident}{die},
            $ident . ' died correctly'
        );
        next;
    }

    is( $trap->leaveby, 'return', $ident . ' returned correctly' );
    is( $host,
        $parse_tests{$ident}{hostname},
        'stringify works on: ' . $ident
    );

    isa_ok( $host, "App::ClusterSSH::Host" );

    for my $trap_type (qw/ die /) {
        if ( !$parse_tests{$ident}{$trap_type} ) {
            is( $trap->$trap_type,
                $parse_tests{$ident}{$trap_type},
                "$ident $trap_type"
            );
        }
        else {
            like(
                $trap->$trap_type,
                $parse_tests{$ident}{$trap_type},
                "$ident $trap_type"
            );
        }
    }

    for my $trap_empty (qw/ stdout stderr /) {
        like(
            $trap->$trap_empty,
            $parse_tests{$ident}{$trap_empty} || qr{^$},
            "$ident $trap_empty"
        );
    }
    for my $attr (qw/ hostname type port username realname geometry /) {
        my $method = "get_$attr";
        is( $host->$method,
            $parse_tests{$ident}{$attr},
            "$ident $attr: " . $host->$method
        );
    }

    is( $host->check_ssh_hostname, 0, $ident . ' not from ssh' );
}

# check for a non-existant file
trap {
    $host = App::ClusterSSH::Host->new(
        hostname   => 'ssh_test',
        ssh_config => $Bin . '/some_bad_filename',
    );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'No unexpected STDOUT' );
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host, 'ssh_test', 'stringify works' );
is( $host->check_ssh_hostname, 0, 'check_ssh_hostname ok for ssh_test', );

trap {
    $host = App::ClusterSSH::Host->new(
        hostname   => 'ssh_test',
        ssh_config => $Bin . '/10host_ssh_config',
    );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'No unexpected STDOUT' );
isa_ok( $host, "App::ClusterSSH::Host" );
is( $host, 'ssh_test', 'stringify works' );
is( $host->check_ssh_hostname, 0, 'check_ssh_hostname ok for ssh_test', );
is( $host->get_type, q{}, 'hostname type is correct for ssh_test', );

for my $ssh_file (qw/ 10host_ssh_config 10host_ssh_include/) {
    my @hosts = (
        'server1',  'server2',
        'server3',  'server4',
        'server-5', 'server5.domain.name',
        'server-6.domain.name'
    );
    push @hosts, 'server_ssh_included' if($ssh_file =~ m/include/);
    for my $hostname (@hosts)
    {

        $host = undef;
        is( $host, undef, 'starting afresh for ssh hostname checks' );

        trap {
            $host = App::ClusterSSH::Host->new(
                hostname   => $hostname,
                ssh_config => $Bin . '/'. $ssh_file,
            );
        };
        is( $trap->leaveby, 'return', 'returned ok' );
        is( $trap->die,     undef,    'returned ok' );
        is( $trap->stdout,  '',       'No unexpected STDOUT' );
        isa_ok( $host, "App::ClusterSSH::Host" );
        is( $host, $hostname, 'stringify works' );
        is( $host->check_ssh_hostname, 1,
            'check_ssh_hostname ok for ' . $hostname );
        is( $host->get_realname, $hostname,   'realname set' );
        is( $host->get_geometry, q{},         'geometry set' );
        is( $host->get_type,     'ssh_alias', 'geometry set' );
    }
}

done_testing();
