use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

#use Test::More tests => 57;
use Test::More qw( no_plan );
use Test::Trap;
use Test::Deep;

BEGIN { use_ok( "ClusterSSH::Config::Base", ) }

# force default language for tests
ClusterSSH::Config::Base->set_lang('en');

my $config;
my $return;
my %attributes;
my %expected;
my $test_file;

trap {
    $config = ClusterSSH::Config::Base->new();
};
is( $config,        undef, 'object not defined on bad new' );
is( $trap->leaveby, 'die', 'died ok' );
like(
    $trap->die,
    qr/^Filename not provided to module ClusterSSH::Config::Base at/,
    'die message ok'
);
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Expecting no STDOUT' );

$test_file = "$Bin/${Script}_not_there";
trap {
    $config = ClusterSSH::Config::Base->new( { filename => $test_file } );
};
is( $config,        undef, 'object not defined on bad new' );
is( $trap->leaveby, 'die', 'died ok' );
like( $trap->die, qr/^File .* does not exist./, 'die message ok' );
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Expecting no STDOUT' );

$test_file = "$Bin/${Script}_test1_symlink";
trap {
    $config = ClusterSSH::Config::Base->new( { filename => $test_file } );
};
isa_ok( $config, 'ClusterSSH::Config::Base' );
is( $trap->leaveby,        'return',   'returned ok' );
is( $trap->die,            undef,      'not died' );
is( $trap->stderr,         '',         'Expecting no STDERR' );
is( $trap->stdout,         '',         'Expecting no STDOUT' );
is( $config->get_filename, $test_file, "filename is correct" );

$test_file = "$Bin/${Script}_test1_real";
trap {
    $config = ClusterSSH::Config::Base->new( { filename => $test_file } );
};
isa_ok( $config, 'ClusterSSH::Config::Base' );
is( $trap->leaveby,        'return',   'returned ok' );
is( $trap->die,            undef,      'not died' );
is( $trap->stderr,         '',         'Expecting no STDERR' );
is( $trap->stdout,         '',         'Expecting no STDOUT' );
is( $config->get_filename, $test_file, "filename is correct" );

trap {
    $config->_get_config_hash();
};
is( $trap->leaveby, 'die', 'died ok' );
like(
    $trap->die, qr/^This method should have been replaced/, 'die message ok');
is( $trap->stderr, '', 'Expecting no STDERR' );
is( $trap->stdout, '', 'Expecting no STDOUT' );
