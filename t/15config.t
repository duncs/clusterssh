use strict;
use warnings;

# Force use of English in tests for the moment, for those users that
# have a different locale set, since errors are hardcoded below
use POSIX qw(setlocale locale_h);
setlocale( LC_ALL, "C" );

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

# fix path for finding our fake xterm on headless systems that do
# not have it installed, such as TravisCI via github
BEGIN {
    $ENV{PATH} = $ENV{PATH} . ':' . $Bin . '/bin';
}

use Test::More;
use Test::Trap;
use File::Which qw(which);
use File::Temp qw(tempdir);
use Test::Differences;

use Readonly;

BEGIN {
    use_ok("App::ClusterSSH::Config") || BAIL_OUT('failed to use module');
}

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
    key_quit                => "Alt-q",
    key_addhost             => "Control-Shift-plus",
    key_clientname          => "Alt-n",
    key_history             => "Alt-h",
    key_localname           => "Alt-l",
    key_retilehosts         => "Alt-r",
    key_macros_enable       => "Alt-p",
    key_paste               => "Control-v",
    key_username            => "Alt-u",
    mouse_paste             => "Button-2",
    auto_quit               => "yes",
    auto_close              => 5,
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

    ssh => '/usr/bin/ssh',

    console      => 'console',
    console_args => '',
    rsh          => 'rsh',
    rsh_args     => "",
    telnet       => 'telnet',
    telnet_args  => "",
    ssh          => 'ssh',
    ssh_args     => "",
    sftp         => 'sftp',
    sftp_args    => "",

    extra_tag_file           => "",
    extra_cluster_file       => "",
    external_cluster_command => '',

    unmap_on_redraw => "no",

    show_history   => 0,
    history_width  => 40,
    history_height => 10,

    command             => q{},
    title               => q{15CONFIG.T},
    comms               => q{ssh},
    hide_menu           => 0,
    max_host_menu_items => 30,

    macros_enabled   => 'yes',
    macro_servername => '%s',
    macro_hostname   => '%h',
    macro_username   => '%u',
    macro_newline    => '%n',
    macro_version    => '%v',

    max_addhost_menu_cluster_items => 6,
    menu_send_autotearoff          => 0,
    menu_host_autotearoff          => 0,

    unique_servers    => 0,
    use_all_a_records => 0,
    use_natural_sort  => 0,

    send_menu_xml_file => $ENV{HOME} . '/.clusterssh/send_menu',

    # Debian #842965
    auto_wm_decoration_offsets => "no",

    # other bits inheritted from App::ClusterSSH::Base
    lang => 'en',
    user => '',
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
    'Unknown configuration parameters: doesnt_exist,whoops' . $/,
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
isa_ok( $trap->die, 'App::ClusterSSH::Exception::LoadFile' );
is( $trap->die,
    "Unable to read file $file: No such file or directory" . $/,
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
    'Unknown configuration parameters: missing,rubbish' . $/,
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
is( $trap->stderr, q{}, 'Expecting no STDERR' );

note('find_binary tests');
my $path;
$config = App::ClusterSSH::Config->new();
trap {
    $path = $config->find_binary();
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
isa_ok( $config,    "App::ClusterSSH::Config" );
is( $trap->die, 'argument not provided' . $/, 'die message correct' );
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
is( $trap->die,
    '"missing" binary not found - please amend $PATH or the cssh config file'
        . $/,
    'die message correct'
);
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );

trap {
    $path = $config->find_binary('ls');
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );
is( $path, 'ls', 'Found correct path to "ls"' );

# check for a binary already found
my $newpath;
trap {
    $newpath = $config->find_binary($path);
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );
is( $path, 'ls',     'Found correct path to "ls"' );
is( $path, $newpath, 'No change made from find_binary' );

# give false path to force another search
trap {
    $newpath = $config->find_binary( '/does/not/exist/' . $path );
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );
is_deeply( $config, \%expected, 'amended config is correct' );
is( $path, 'ls',     'Found correct path to "ls"' );
is( $path, $newpath, 'No change made from find_binary' );

note('Checks on loading configs');
note('empty dir');
$ENV{HOME} = tempdir( CLEANUP => 1 );
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs();
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->die,    undef, 'die message correct' );
is( $trap->stdout, q{},   'Expecting no STDOUT' );
is( $trap->stderr,
    'Created new configuration file within $HOME/.clusterssh/' . $/,
    'Got correct STDERR output for .csshrc'
);

#note(qx/ls -laR $ENV{HOME}/);
ok( -d $ENV{HOME} . '/.clusterssh',        '.clusterssh dir exists' );
ok( -f $ENV{HOME} . '/.clusterssh/config', '.clusterssh config file exists' );
is_deeply( $config, \%expected, 'amended config is correct' );
$ENV{HOME} = undef;

note('.csshrc warning');
$ENV{HOME} = tempdir( CLEANUP => 1 );
open( my $csshrc, '>', $ENV{HOME} . '/.csshrc' );
print $csshrc 'auto_quit = no', $/;
close($csshrc);
$expected{auto_quit} = 'no';
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs();
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->die,    undef, 'die message correct' );
is( $trap->stdout, q{},   'Expecting no STDOUT' );
is( $trap->stderr,
    'Moved $HOME/.csshrc to $HOME/.csshrc.DISABLED'
        . $/
        . 'Created new configuration file within $HOME/.clusterssh/'
        . $/,
    'Got correct STDERR output for .csshrc'
);
ok( -d $ENV{HOME} . '/.clusterssh',        '.clusterssh dir exists' );
ok( -f $ENV{HOME} . '/.clusterssh/config', '.clusterssh config file exists' );
is_deeply( $config, \%expected, 'amended config is correct' );

note('.csshrc warning and .clusterssh dir plus config');

# need to recreate .csshrc as it was just moved
open( $csshrc, '>', $ENV{HOME} . '/.csshrc' );
print $csshrc 'auto_quit = no', $/;
close($csshrc);
$expected{auto_quit} = 'no';
open( $csshrc, '>', $ENV{HOME} . '/.clusterssh/config' );
print $csshrc 'window_tiling = no', $/;
close($csshrc);
$expected{window_tiling} = 'no';
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs();
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->die,    undef, 'die message correct' );
is( $trap->stdout, q{},   'Expecting no STDOUT' );
is( $trap->stderr,
    'Moved $HOME/.csshrc to $HOME/.csshrc.DISABLED' . $/,
    'Got correct STDERR output for .csshrc'
);
ok( -d $ENV{HOME} . '/.clusterssh',        '.clusterssh dir exists' );
ok( -f $ENV{HOME} . '/.clusterssh/config', '.clusterssh config file exists' );
is_deeply( $config, \%expected, 'amended config is correct' );

note('no .csshrc warning and .clusterssh dir');
unlink( $ENV{HOME} . '/.csshrc' );
$expected{auto_quit} = 'yes';
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs();
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->die,    undef, 'die message correct' );
is( $trap->stdout, q{},   'Expecting no STDOUT' );
is( $trap->stderr, '',    'Expecting no STDERR' );
ok( -d $ENV{HOME} . '/.clusterssh',        '.clusterssh dir exists' );
ok( -f $ENV{HOME} . '/.clusterssh/config', '.clusterssh config file exists' );
is_deeply( $config, \%expected, 'amended config is correct' );

note('no .csshrc warning, .clusterssh dir plus config + extra config');
open( $csshrc, '>', $ENV{HOME} . '/clusterssh.config' );
print $csshrc 'terminal_args = something', $/;
close($csshrc);
$expected{terminal_args} = 'something';
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs( $ENV{HOME} . '/clusterssh.config' );
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->die,    undef, 'die message correct' );
is( $trap->stdout, q{},   'Expecting no STDOUT' );
is( $trap->stderr, '',    'Expecting no STDERR' );
ok( -d $ENV{HOME} . '/.clusterssh',        '.clusterssh dir exists' );
ok( -f $ENV{HOME} . '/.clusterssh/config', '.clusterssh config file exists' );
is_deeply( $config, \%expected, 'amended config is correct' );

note('no .csshrc warning, .clusterssh dir plus config + more extra configs');
open( $csshrc, '>', $ENV{HOME} . '/.clusterssh/config_ABC' );
print $csshrc 'ssh_args = something', $/;
close($csshrc);
$expected{ssh_args} = 'something';
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs( $ENV{HOME} . '/clusterssh.config', 'ABC' );
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->die,    undef, 'die message correct' );
is( $trap->stdout, q{},   'Expecting no STDOUT' );
is( $trap->stderr, '',    'Expecting no STDERR' );
ok( -d $ENV{HOME} . '/.clusterssh',        '.clusterssh dir exists' );
ok( -f $ENV{HOME} . '/.clusterssh/config', '.clusterssh config file exists' );
is_deeply( $config, \%expected, 'amended config is correct' );

note('check .clusterssh file is an error');
$ENV{HOME} = tempdir( CLEANUP => 1 );
open( $csshrc, '>', $ENV{HOME} . '/.clusterssh' );
print $csshrc 'should_be_dir_not_file = PROBLEM', $/;
close($csshrc);
$config = App::ClusterSSH::Config->new();
trap {
    $config->write_user_config_file();
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
isa_ok( $config,    "App::ClusterSSH::Config" );
is( $trap->die,
    'Unable to create directory $HOME/.clusterssh: File exists' . $/,
    'die message correct'
);
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );

note('check failure to write default config is caught');
$ENV{HOME} = tempdir( CLEANUP => 1 );
mkdir( $ENV{HOME} . '/.clusterssh' );
mkdir( $ENV{HOME} . '/.clusterssh/config' );
$config = App::ClusterSSH::Config->new();
trap {
    $config->write_user_config_file();
};
is( $trap->leaveby, 'die', 'died ok' );
isa_ok( $trap->die, 'App::ClusterSSH::Exception::Config' );
isa_ok( $config,    "App::ClusterSSH::Config" );
is( $trap->die,
    'Unable to write default $HOME/.clusterssh/config: Is a directory' . $/,
    'die message correct'
);
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );

note('check .clusterssh errors via load_configs are not fatal');
$ENV{HOME} = tempdir( CLEANUP => 1 );
open( $csshrc, '>', $ENV{HOME} . '/.clusterssh' );
print $csshrc 'should_be_dir_not_file = PROBLEM', $/;
close($csshrc);
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs();
};
is( $trap->leaveby, 'return', 'died ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr,
    q{Unable to create directory $HOME/.clusterssh: File exists} . $/ . $/,
    'Expecting no STDERR'
);

SKIP: {
    skip "Test inappropriate when running as root", 5 if $< == 0;
    note('move of .csshrc failure');
    $ENV{HOME} = tempdir( CLEANUP => 1 );
    open( $csshrc, '>', $ENV{HOME} . '/.csshrc' );
    print $csshrc "Something", $/;
    close($csshrc);
    open( $csshrc, '>', $ENV{HOME} . '/.csshrc.DISABLED' );
    print $csshrc "Something else", $/;
    close($csshrc);
    chmod( 0666, $ENV{HOME} . '/.csshrc.DISABLED', $ENV{HOME} );
    $config = App::ClusterSSH::Config->new();
    trap {
        $config->write_user_config_file();
    };
    is( $trap->leaveby, 'die', 'died ok' );
    isa_ok( $config, "App::ClusterSSH::Config" );
    is( $trap->stdout, q{}, 'Expecting no STDOUT' );
    is( $trap->stderr, q{}, 'Expecting no STDERR' );
    is( $trap->die,
        q{Unable to create directory $HOME/.clusterssh: Permission denied}
            . $/,
        'Expected die msg ' . $trap->stderr
    );
    chmod( 0755, $ENV{HOME} . '/.csshrc.DISABLED', $ENV{HOME} );
}

note('check failure to write default config is caught');
$ENV{HOME} = tempdir( CLEANUP => 1 );
mkdir( $ENV{HOME} . '/.clusterssh' );
mkdir( $ENV{HOME} . '/.clusterssh/config' );
$config = App::ClusterSSH::Config->new();
trap {
    $config->load_configs();
};
is( $trap->leaveby, 'return', 'returned ok' );
isa_ok( $config, "App::ClusterSSH::Config" );
isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->stdout, q{}, 'Expecting no STDOUT' );
is( $trap->stderr,
    q{Unable to write default $HOME/.clusterssh/config: Is a directory}
        . $/
        . $/,
    'Expecting no STDERR'
);

note('Checking dump');
$config = App::ClusterSSH::Config->new(
    send_menu_xml_file => $ENV{HOME} . '/.clusterssh/send_menu', );

trap {
    $config->dump();
};
my $expected = qq{# Configuration dump produced by "cssh -d"
auto_close=5
auto_quit=yes
auto_wm_decoration_offsets=no
console=console
console_args=
console_position=
external_cluster_command=
extra_cluster_file=
extra_tag_file=
hide_menu=0
history_height=10
history_width=40
key_addhost=Control-Shift-plus
key_clientname=Alt-n
key_history=Alt-h
key_localname=Alt-l
key_macros_enable=Alt-p
key_paste=Control-v
key_quit=Alt-q
key_retilehosts=Alt-r
key_username=Alt-u
lang=en
macro_hostname=%h
macro_newline=%n
macro_servername=%s
macro_username=%u
macro_version=%v
macros_enabled=yes
max_addhost_menu_cluster_items=6
max_host_menu_items=30
menu_host_autotearoff=0
menu_send_autotearoff=0
mouse_paste=Button-2
rsh=rsh
rsh_args=
screen_reserve_bottom=60
screen_reserve_left=0
screen_reserve_right=0
screen_reserve_top=0
send_menu_xml_file=} . $ENV{HOME} . qq{/.clusterssh/send_menu
sftp=sftp
sftp_args=
show_history=0
ssh=ssh
ssh_args=
telnet=telnet
telnet_args=
terminal=xterm
terminal_allow_send_events=-xrm '*.VT100.allowSendEvents:true'
terminal_args=
terminal_bg_style=dark
terminal_colorize=1
terminal_decoration_height=10
terminal_decoration_width=8
terminal_font=6x13
terminal_reserve_bottom=0
terminal_reserve_left=5
terminal_reserve_right=0
terminal_reserve_top=5
terminal_size=80x24
terminal_title_opt=-T
unique_servers=0
unmap_on_redraw=no
use_all_a_records=0
use_hotkeys=yes
use_natural_sort=0
#user=
window_tiling=yes
window_tiling_direction=right
};

isa_ok( $config, "App::ClusterSSH::Config" );
is( $trap->die, undef, 'die message correct' );
eq_or_diff( $trap->stdout, $expected, 'Expecting no STDOUT' );
is( $trap->stderr, q{}, 'Expecting no STDERR' );

done_testing();
