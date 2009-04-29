use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 57;
use Test::Trap;

BEGIN { use_ok( "ClusterSSH::Base", qw/ ident / ) }

# force default language for tests
ClusterSSH::Base->set_lang( undef, 'en' );

eval { ident ''; };
like( $@, qr/^Reference not passed to ident/, 'Picked up exception' );

my $scalar;
eval { ident $scalar; };
like( $@, qr/^Reference not passed to ident/, 'Picked up exception' );

like( ident( \$scalar ), qr/^\d+$/, 'ident returned OK' );

my $base;

$base = ClusterSSH::Base->new();
isa_ok( $base, 'ClusterSSH::Base' );

is( ident($base), $base->id, 'id works correctly' );

diag('testing output') if ( $ENV{TEST_VERBOSE} );
trap {
    $base->output('testing');
};
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout =~ tr/\n//, 1, 'got correct number of print lines' );
like( $trap->stdout, qr/\Atesting\n\Z/xsm,
    'checking for expected print output' );

diag('Testing debug output') if ( $ENV{TEST_VERBOSE} );

for my $level ( 0 .. 9 ) {
    $base->set_debug_level($level);
    is( $base->debug_level(), $level, 'debug level is correct' );

    trap {
        for my $level ( 0 .. 9 ) {
            $base->debug( $level, 'test' );
        }
    };

    is( $trap->stderr, '', 'Expecting no STDERR' );
    is( $trap->stdout =~ tr/\n//,
        $level, 'got correct number of debug lines' );
    like( $trap->stdout, qr/(?:test\n){$level}/xsm,
        'checking for expected debug output' );
}

trap {
    $base->set_debug_level();
};
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Expecting no STDOUT' );
like( $trap->die, qr/^Debug level not provided at/,
    'Got correct croak text' );

$base->set_debug_level(10);
is( $base->debug_level(), 9, 'checking debug_level reset to 9' );

$base = undef;
trap {
    $base = ClusterSSH::Base->new( { debug => 7, } );
};
isa_ok( $base, 'ClusterSSH::Base' );
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout =~ tr/\n//, 2, 'got new() debug output lines' );
like(
    $trap->stdout,
    qr/Arguments\sto\sClusterSSH::Base->new.*debug\s=>\s7$/xsm,
    'got expected new() output'
);
