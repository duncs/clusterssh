use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use Sys::Hostname;

BEGIN { use_ok('App::ClusterSSH::Gui::Terminal::Command') }

# force default language for tests
App::ClusterSSH::Gui::Terminal::Command->set_lang('en');

my $obj;

trap {
    $obj = App::ClusterSSH::Gui::Terminal::Command->new();
};
is( $trap->leaveby, 'die', 'returned ok' );
like( $trap->die, qr/command is undefined at /, 'Got appropriate croak message' );
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Expecting no STDOUT' );

trap {
    $obj = App::ClusterSSH::Gui::Terminal::Command->new( command => 'true' );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stdout,  '',       'Expected no STDERR' );
isa_ok( $obj, 'App::ClusterSSH::Gui::Terminal::Command' );

my $script;
trap {
    $script = $obj->script();
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stdout,  '',       'Expected no STDERR' );
isa_ok( $obj, 'App::ClusterSSH::Gui::Terminal::Command' );

my $output;
trap {
    $output = qx/$^X -e '$script' -- -c hostname/;
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stdout,  '',       'Expected no STDERR' );
isa_ok( $obj, 'App::ClusterSSH::Gui::Terminal::Command' );
chomp($output);
is( $output, hostname(),      'Hostname output as expected');

trap {
    $output = qx/$^X -e '$script' -- -d 3 -c hostname 2>&1/;
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expected no STDERR' );
isa_ok( $obj, 'App::ClusterSSH::Gui::Terminal::Command' );
chomp($output);
is( $output, 'Running:  hostname'.$/.hostname(),      'Hostname output as expected');

done_testing();
