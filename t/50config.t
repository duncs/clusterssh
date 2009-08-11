use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

#use Test::More tests => 57;
use Test::More qw( no_plan );
use Test::Trap;
use Test::Deep;

BEGIN { use_ok( "ClusterSSH::Config", ) }

# force default language for tests
ClusterSSH::Config->set_lang('en');

my $config;
my $return;
my %attributes;
my %expected;

$config = ClusterSSH::Config->new();
isa_ok( $config, 'ClusterSSH::Config' );

%attributes = $config->get_config_hash;
%expected   = (
    'key_history'     => 'Alt-h',
    'key_retilehosts' => 'Alt-r',
    'auto_quit'       => 'yes',
    'key_paste'       => 'Control-v',
    'key_addhost'     => 'Control-Shift-plus',
    'key_clientname'  => 'Alt-n',
    'command'         => '',
    'key_quit'        => 'Control-q',
);
is_deeply( \%attributes, \%expected, 'default config is correct' );

trap {
    $return = $config->validate(%attributes);
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $return,        $config,  'returned object' );

$return = $config->_set_config_by_hash( { 'rubbish' => 'rubbish' } );
trap {
    $return = $config->validate(%attributes);
};
is( $trap->leaveby, 'die', 'returned ok' );
like( $trap->die, qr/^Unknown configuration options: rubbish at /,
    'returned ok' );
is( $trap->stdout, '',      'Expecting no STDOUT' );
is( $trap->stderr, '',      'Expecting no STDERR' );
is( $return,       $config, 'returned object' );
