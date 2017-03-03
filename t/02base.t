use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;

BEGIN { use_ok('App::ClusterSSH::Base') }

# force default language for tests
App::ClusterSSH::Base->set_lang('en');

my $base;

$base = App::ClusterSSH::Base->new();
isa_ok( $base, 'App::ClusterSSH::Base' );

diag('testing output') if ( $ENV{TEST_VERBOSE} );
trap {
    $base->stdout_output('testing');
};
is( $trap->leaveby,           'return', 'returned ok' );
is( $trap->die,               undef,    'returned ok' );
is( $trap->stderr,            '',       'Expecting no STDERR' );
is( $trap->stdout =~ tr/\n//, 1,        'got correct number of print lines' );
like( $trap->stdout, qr/\Atesting\n\Z/xsm,
    'checking for expected print output' );

diag('Testing debug output') if ( $ENV{TEST_VERBOSE} );

for my $level ( 0 .. 9 ) {
    $base->set_debug_level($level);
    is( $base->debug_level(), $level, 'debug level is correct' );

    trap {
        for my $log_level ( 0 .. 9 ) {
            $base->debug( $log_level, 'test' );
        }
    };

    is( $trap->leaveby, 'return', 'returned ok' );
    is( $trap->die,     undef,    'returned ok' );
    is( $trap->stderr,  '',       'Expecting no STDERR' );
    is( $trap->stdout =~ tr/\n//,
        $level + 1, 'got correct number of debug lines' );
    like( $trap->stdout, qr/(?:test\n){$level}/xsm,
        'checking for expected debug output' );
}

my $level;
trap {
    $level = $base->set_debug_level();
};
isa_ok( $trap->die, 'App::ClusterSSH::Exception',
    'Caught exception object OK' );
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stderr,  '',    'Expecting no STDERR' );
is( $trap->stdout,  '',    'Expecting no STDOUT' );
like( $trap->die, qr/^Debug level not provided/, 'Got correct croak text' );

$base->set_debug_level(10);
is( $base->debug_level(), 9, 'checking debug_level reset to 9' );

$base = undef;
trap {
    $base = App::ClusterSSH::Base->new( debug => 6, );
};
isa_ok( $base, 'App::ClusterSSH::Base' );
is( $trap->leaveby,           'return', 'returned ok' );
is( $trap->die,               undef,    'returned ok' );
is( $trap->stderr,            '',       'Expecting no STDERR' );
is( $trap->stdout =~ tr/\n//, 1,        'got new() debug output lines' );
like(
    $trap->stdout,
    qr/^Setting\slanguage\sto\s"en"/xsm,
    'got expected new() output'
);

$base = undef;
trap {
    $base = App::ClusterSSH::Base->new( debug => 6, lang => 'en' );
};
isa_ok( $base, 'App::ClusterSSH::Base' );
is( $trap->leaveby,           'return', 'returned ok' );
is( $trap->die,               undef,    'returned ok' );
is( $trap->stderr,            '',       'Expecting no STDERR' );
is( $trap->stdout =~ tr/\n//, 1,        'got new() debug output lines' );
like(
    $trap->stdout,
    qr/^Setting\slanguage\sto\s"en"/xsm,
    'got expected new() output'
);

$base = undef;
trap {
    $base = App::ClusterSSH::Base->new( debug => 6, lang => 'rubbish' );
};
isa_ok( $base, 'App::ClusterSSH::Base' );
is( $trap->leaveby,           'return', 'returned ok' );
is( $trap->die,               undef,    'returned ok' );
is( $trap->stderr,            '',       'Expecting no STDERR' );
is( $trap->stdout =~ tr/\n//, 1,        'got new() debug output lines' );
like(
    $trap->stdout,
    qr/^Setting\slanguage\sto\s"rubbish"/xsm,
    'got expected new() output'
);

$base = undef;
trap {
    $base = App::ClusterSSH::Base->new( debug => 7, );
};
isa_ok( $base, 'App::ClusterSSH::Base' );
is( $trap->leaveby,           'return', 'returned ok' );
is( $trap->die,               undef,    'returned ok' );
is( $trap->stderr,            '',       'Expecting no STDERR' );
is( $trap->stdout =~ tr/\n//, 3,        'got new() debug output lines' );
like(
    $trap->stdout,
    qr/^Setting\slanguage\sto\s"en".Arguments\sto\sApp::ClusterSSH::Base->new.*debug\s=>\s7,$/xsm,
    'got expected new() output'
);

# config tests
$base = undef;
my $get_config;
my $object;
trap {
    $base = App::ClusterSSH::Base->new( debug => 3, );
};
isa_ok( $base, 'App::ClusterSSH::Base' );
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );

$base = undef;
trap {
    $base = App::ClusterSSH::Base->new( debug => 3, parent => 'guardian' );
};
isa_ok( $base, 'App::ClusterSSH::Base' );
is( $trap->leaveby, 'return',   'returned ok' );
is( $trap->die,     undef,      'returned ok' );
is( $trap->stderr,  '',         'Expecting no STDERR' );
is( $trap->stdout,  '',         'Expecting no STDOUT' );
is( $base->parent,  'guardian', 'Expecting no STDOUT' );

trap {
    $get_config = $base->config();
};
isa_ok( $trap->die, 'App::ClusterSSH::Exception',
    'Caught exception object OK' );
is( $trap->leaveby, 'die', 'died ok' );
like( $trap->die, qr/^config has not yet been set/,
    'Got correct croak text' );
is( $trap->stderr, '',    'Expecting no STDERR' );
is( $trap->stdout, '',    'Expecting not STDOUT' );
is( $get_config,   undef, 'config left empty' );

trap {
    $object = $base->set_config();
};
isa_ok( $trap->die, 'App::ClusterSSH::Exception',
    'Caught exception object OK' );
is( $trap->leaveby, 'die', 'died ok' );
like( $trap->die, qr/^passed config is empty/, 'Got correct croak text' );
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Expecting no STDOUT' );

trap {
    $object = $base->set_config('set to scalar');
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'config set ok' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
like(
    $trap->stdout,
    qr/^Setting\sapp\sconfiguration/xsm,
    'Got expected STDOUT'
);
isa_ok( $object, 'App::ClusterSSH::Base' );

trap {
    $get_config = $base->config();
};
is( $trap->leaveby, 'return',        'returned ok' );
is( $trap->die,     undef,           'returned ok' );
is( $trap->stderr,  '',              'Expecting no STDERR' );
is( $trap->stdout,  '',              'Expecting not STDOUT' );
is( $get_config,    'set to scalar', 'config set as expected' );

trap {
    $object = $base->set_config('set to another scalar');
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception',
    'Caught exception object OK' );
like(
    $trap->die,
    qr/^config\shas\salready\sbeen\sset/,
    'config cannot be reset'
);
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Got expected STDOUT' );

trap {
    $object = $base->set_config();
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception',
    'Caught exception object OK' );
like(
    $trap->die,
    qr/^config\shas\salready\sbeen\sset/,
    'config cannot be reset'
);
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Got expected STDOUT' );

# basic checks - validity of config is tested elsewhere
my %config;
trap {
    %config = $object->load_file;
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception',
    'Caught exception object OK' );
is( $trap->die,
    q{"filename" arg not passed},
    'missing filename arg die message'
);
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Got expected STDOUT' );

trap {
    %config = $object->load_file( filename => $Bin . '/15config.t.file1' );
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception',
    'Caught exception object OK' );
is( $trap->die, q{"type" arg not passed}, 'missing type arg die message' );
is( $trap->stderr, '', 'Expecting no STDERR' );

done_testing();
