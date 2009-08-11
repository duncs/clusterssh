use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

#use Test::More tests => 57;
use Test::More qw( no_plan );
use Test::Trap;
use Test::Deep;

BEGIN { use_ok( "ClusterSSH::Config::File", ) }

# force default language for tests
ClusterSSH::Config::File->set_lang('en');

my $config;
my $return;
my %attributes;
my %expected;
my $test_file;

$test_file = "$Bin/${Script}_test1";
trap {
    $config = ClusterSSH::Config::File->new( { filename => $test_file } );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
isa_ok( $config, 'ClusterSSH::Config::File' );
is( $config->get_filename, $test_file, "filename is correct" );

trap {
    %attributes = %{ $config->get_config_hash };
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );

%expected = (
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

$test_file = "$Bin/${Script}_test2";
trap {
    $config = ClusterSSH::Config::File->new( { filename => $test_file } );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
isa_ok( $config, 'ClusterSSH::Config::File' );
is( $config->get_filename, $test_file, "filename is correct" );

trap {
    %attributes = %{ $config->get_config_hash };
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );

%expected = (
    auto_quit                    => "yes",
    command                      => "",
    comms                        => "ssh",
    console_position             => "",
    extra_cluster_file           => "",
    history_height               => 10,
    history_width                => 40,
    key_addhost                  => "Control-Shift-plus",
    key_clientname               => "Alt-n",
    key_history                  => "Alt-h",
    key_paste                    => "Control-v",
    key_quit                     => "Control-q",
    key_retilehosts              => "Alt-r",
    max_host_menu_items          => 30,
    method                       => "ssh",
    mouse_paste                  => "Button-2",
    rsh_args                     => "",
    "screen_reserve_bottom"      => 60,
    screen_reserve_left          => 0,
    screen_reserve_right         => 0,
    screen_reserve_top           => 0,
    show_history                 => 0,
    ssh                          => "/usr/bin/ssh",
    ssh_args                     => "-x -o ConnectTimeout=10",
    telnet_args                  => "",
    terminal                     => "/usr/bin/xterm",
    "terminal_allow_send_events" => "-xrm '*.VT100.allowSendEvents:true'",
    terminal_args                => "",
    terminal_bg_style            => "dark",
    terminal_colorize            => 1,
    "terminal_decoration_height" => 10,
    "terminal_decoration_width"  => 8,
    terminal_font                => "6x13",
    "terminal_reserve_bottom"    => 0,
    "terminal_reserve_left"      => 5,
    "terminal_reserve_right"     => 0,
    terminal_reserve_top         => 5,
    terminal_size                => "80x24",
    terminal_title_opt           => "-T",
    title                        => "CSSH",
    unmap_on_redraw              => "no",
    use_hotkeys                  => "yes",
    window_tiling                => "yes",
    "window_tiling_direction"    => "right",
);
is_deeply( \%attributes, \%expected, 'default config is correct' );
