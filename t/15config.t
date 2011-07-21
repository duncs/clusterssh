use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);

use Readonly;

BEGIN { use_ok("App::ClusterSSH::Config") }

my $config;

$config = App::ClusterSSH::Config->new();
isa_ok( $config, 'App::ClusterSSH::Config' );

Readonly::Hash my %default_config => {
    terminal                   => "xterm",
    terminal_args              => "",
    terminal_title_opt         => "-T",
    terminal_colorize          => 1,
    terminal_bg_style          => 'dark',
    terminal_allow_send_events => "-xrm '*.VT100.allowSendEvents:true'",
    terminal_font              => "6x13",
    terminal_size              => "80x24",

    use_hotkeys             => "yes",
    key_quit                => "Control-q",
    key_addhost             => "Control-Shift-plus",
    key_clientname          => "Alt-n",
    key_history             => "Alt-h",
    key_retilehosts         => "Alt-r",
    key_paste               => "Control-v",
    mouse_paste             => "Button-2",
    auto_quit               => "yes",
    window_tiling           => "yes",
    window_tiling_direction => "right",
    console_position        => "",

    screen_reserve_top    => 0,
    screen_reserve_bottom => 60,
    screen_reserve_left   => 0,
    screen_reserve_right  => 0,

    terminal_reserve_top    => 5,
    terminal_reserve_bottom => 0,
    terminal_reserve_left   => 5,
    terminal_reserve_right  => 0,

    terminal_decoration_height => 10,
    terminal_decoration_width  => 8,

    rsh_args    => "",
    telnet_args => "",
    ssh_args    => "",

    extra_cluster_file => "",

    unmap_on_redraw => "no",

    show_history   => 0,
    history_width  => 40,
    history_height => 10,

    command             => q{},
    max_host_menu_items => 30,

    max_addhost_menu_cluster_items => 6,
    menu_send_autotearoff          => 0,
    menu_host_autotearoff          => 0,

    send_menu_xml_file => $ENV{HOME} . '/.csshrc_send_menu',

    # other bits inheritted from App::ClusterSSH::Base
    debug => 0,
    lang  => 'en',

};
my %expected = %default_config;
is_deeply( $config, \%expected, 'default config is correct' );

$config = App::ClusterSSH::Config->new();
trap {
    $config = $config->validate_args(
        whoops       => 'not there',
        doesnt_exist => 'whoops',
    );
};
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
is( $trap->die,
    'Unknown configuration parameters: doesnt_exist,whoops',
    'got correct error message'
);
is_deeply(
    $trap->die->unknown_config,
    [ 'doesnt_exist', 'whoops' ],
    'Picked up unknown config array'
);
isa_ok( $config, "App::ClusterSSH::Config" );

$expected{extra_cluster_file}             = '/etc/filename';
$expected{rsh_args}                       = 'some args';
$expected{max_addhost_menu_cluster_items} = 120;
trap {
    $config = $config->validate_args(
        extra_cluster_file             => '/etc/filename',
        rsh_args                       => 'some args',
        max_addhost_menu_cluster_items => 120,
    );
};
is( $trap->die, undef, 'validated ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
is_deeply( $config, \%expected, 'default config is correct' );

$config   = App::ClusterSSH::Config->new();
%expected = %default_config;

my $file = "$Bin/$Script.doesntexist";
trap {
    $config = $config->parse_config_file( $file, );
};
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
is( $trap->die,
    "File $file does not exist or cannot be read",
    'got correct error message'
);

$file = "$Bin/$Script.file1";
note("using $file");
$config                          = App::ClusterSSH::Config->new();
%expected                        = %default_config;
$expected{screen_reserve_left}   = 100;
$expected{screen_reserve_right}  = 100;
$expected{screen_reserve_top}    = 100;
$expected{screen_reserve_bottom} = 160;
trap {
    $config = $config->parse_config_file( $file, );
};
is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );

$file = "$Bin/$Script.file2";
note("using $file");
$config   = App::ClusterSSH::Config->new();
%expected = %default_config;
trap {
    $config = $config->parse_config_file( $file, );
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
is( $trap->die,
    'Unknown configuration parameters: missing,rubbish',
    'die message correct'
);
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );

$file = "$Bin/$Script.file3";
note("using $file");
$config   = App::ClusterSSH::Config->new();
%expected = %default_config;
trap {
    $config = $config->parse_config_file( $file, );
};

is( $trap->leaveby, 'return', 'returned ok' );
is( $trap->die,     undef,    'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
{
    local $TODO = "deal with cluster definitions in config file";
    is( $trap->stderr, q{}, 'Expecting no STDERR' );
}

note('find_binary tests');
my $path;
$config = App::ClusterSSH::Config->new();
trap {
    $path = $config->find_binary();
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
isa_ok( $config,    "App::ClusterSSH::Config" );
is( $trap->die, 'argument not provided', 'die message correct' );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );

trap {
    $path = $config->find_binary('missing');
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
isa_ok( $config,    "App::ClusterSSH::Config" );
is( $trap->die, '"missing" binary not found - please amend $PATH or the cssh config file', 'die message correct' );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );

trap {
    $path = $config->find_binary('ls');
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config,    "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );
is($path, which('ls'), 'Found correct path to "ls"');

done_testing();
