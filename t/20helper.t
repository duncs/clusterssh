use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);
use File::Temp qw(tempdir);

use Readonly;

BEGIN {
    use_ok("App::ClusterSSH::Helper") || BAIL_OUT('failed to use module');
}

my $helper;

$helper = App::ClusterSSH::Helper->new();
isa_ok( $helper, 'App::ClusterSSH::Helper' );

my $script;

trap {
    $script = $helper->script;
};
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die, 'No configuration provided or in wrong format', 'no config' );

trap {
    $script = $helper->script( something => 'nothing' );
};
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die, 'No configuration provided or in wrong format',
    'bad format' );

trap {
    $script = $helper->script( { something => 'nothing' } );
};
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );

# ignore stderr here as it will complain about missing xxx_arg var
#is( $trap->stderr, q{}, 'Expecting no STDERR' );
is( $trap->die, q{Config 'comms' not provided}, 'missing arg' );

trap {
    $script = $helper->script( { comms => 'method' } );
};
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die, q{Config 'method' not provided}, 'missing arg' );

trap {
    $script = $helper->script( { comms => 'method', method => 'binary', } );
};
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die, q{Config 'method_args' not provided}, 'missing arg' );

trap {
    $script = $helper->script(
        {   comms       => 'method',
            method      => 'binary',
            method_args => 'rubbish',
            command     => 'echo',
            auto_close  => 0,
        }
    );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die, undef,     'not died' );

trap {
    $script = $helper->script(
        {   comms       => 'method',
            method      => 'binary',
            method_args => 'rubbish',
            command     => 'echo',
            auto_close  => 5,
        }
    );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die, undef,     'not died' );

trap {
    eval { $script };
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die, undef,     'not died' );

done_testing();
