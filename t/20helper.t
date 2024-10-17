use strict;
use warnings;

# Force use of English in tests for the moment, for those users that
# have a different locale set, since errors are hardcoded below
use POSIX qw(setlocale locale_h);
setlocale( LC_ALL, "C" );

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);
use File::Temp  qw(tempdir);

use Readonly;

package App::ClusterSSH::Config;

sub new {
    my ( $class, %args ) = @_;
    my $self = {%args};
    return bless $self, $class;
}

package main;

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

my $mock_config = App::ClusterSSH::Config->new();
trap {
    $script = $helper->script($mock_config);
};
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );

# ignore stderr here as it will complain about missing xxx_arg var
#is( $trap->stderr, q{}, 'Expecting no STDERR' );
is( $trap->die, q{Config 'comms' not provided}, 'missing arg' );

$mock_config->{comms} = 'method';
trap {
    $script = $helper->script($mock_config);
};
is( $trap->leaveby, 'die',                           'returned ok' );
is( $trap->stdout,  q{},                             'Expecting no STDOUT' );
is( $trap->stderr,  q{},                             'Expecting no STDERR' );
is( $trap->die,     q{Config 'method' not provided}, 'missing arg' );

$mock_config->{method} = 'binary';
trap {
    $script = $helper->script($mock_config);
};
is( $trap->leaveby, 'die', 'returned ok' );
is( $trap->stdout,  q{},   'Expecting no STDOUT' );
is( $trap->stderr,  q{},   'Expecting no STDERR' );
is( $trap->die,     q{Config 'method_args' not provided}, 'missing arg' );

$mock_config->{method_args} = 'rubbish';
$mock_config->{command}     = 'echo';
$mock_config->{auto_close}  = 5;
trap {
    $script = $helper->script($mock_config);
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->stdout,  q{},      'Expecting no STDOUT' );
is( $trap->stderr,  q{},      'Expecting no STDERR' );
is( $trap->die,     undef,    'not died' );

trap {
    eval {$script};
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->stdout,  q{},      'Expecting no STDOUT' );
is( $trap->stderr,  q{},      'Expecting no STDERR' );
is( $trap->die,     undef,    'not died' );

done_testing();
