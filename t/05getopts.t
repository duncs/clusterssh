use strict;
use warnings;

# Force use of English in tests for the moment, for those users that
# have a different locale set, since errors are hardcoded below
use POSIX qw(setlocale locale_h);
setlocale( LC_ALL, "C" );

package Test::ClusterSSH::Mock;

# generate purpose object used to simplfy testing

sub new {
    my ( $class, %args ) = @_;
    my $config = {
        comms           => 'testing',
        key_addhost     => 'x',
        key_clientname  => 'x',
        key_localname   => 'x',
        key_quit        => 'x',
        key_retilehosts => 'x',
        key_username    => 'x',
        %args
    };
    return bless $config, $class;
}

sub parent {
    my ($self) = @_;
    return $self;
}

sub VERSION {
    my ($self) = @_;
    return 'TESTING';
}

sub config {
    my ($self) = @_;
    return $self;
}

sub load_configs {
    my ($self) = @_;
    return $self;
}

sub config_file {
    my ($self) = @_;
    return {};
}

1;

package main;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;

BEGIN { use_ok('App::ClusterSSH::Getopt') }

my $getopts;

my $mock_object = Test::ClusterSSH::Mock->new();

$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
isa_ok( $getopts, 'App::ClusterSSH::Getopt' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on new object okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );

$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
isa_ok( $getopts, 'App::ClusterSSH::Getopt' );

trap {
    $getopts->add_option();
};
is( $trap->leaveby, 'die', 'adding an empty option failed' );
is( $trap->die,
    q{No "spec" passed to add_option},
    'empty add_option message'
);
is( $trap->stdout, '', 'Expecting no STDOUT' );
is( $trap->stderr, '', 'Expecting no STDERR' );

trap {
    $getopts->add_option( spec => 'option' );
};
is( $trap->leaveby, 'return', 'adding an empty option failed' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on object with spec okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );
trap {
    $getopts->option;
};
is( $trap->leaveby,   'return', 'calling option' );
is( $trap->stdout,    '',       'Expecting no STDOUT' );
is( $trap->stderr,    '',       'Expecting no STDERR' );
is( $trap->die,       undef,    'Expecting no die message' );
is( $getopts->option, undef,    'Expecting no die message' );

local @ARGV = '--option1';
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->add_option( spec => 'option1' );
};
is( $trap->leaveby, 'return', 'adding an empty option failed' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on object with spec okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );
trap {
    $getopts->option1;
};
is( $trap->leaveby,    'return', 'calling option' );
is( $trap->stdout,     '',       'Expecting no STDOUT' );
is( $trap->stderr,     '',       'Expecting no STDERR' );
is( $trap->die,        undef,    'Expecting no die message' );
is( $getopts->option1, 1,        'Expecting no die message' );

local @ARGV = '';    # @ARGV is never undef, but an empty string
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->add_option( spec => 'option1', default => 5 );
};
is( $trap->leaveby, 'return', 'adding an empty option with a default value' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on object with spec okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );
trap {
    $getopts->option1;
};
is( $trap->leaveby,    'return', 'calling option' );
is( $trap->stdout,     '',       'Expecting no STDOUT' );
is( $trap->stderr,     '',       'Expecting no STDERR' );
is( $trap->die,        undef,    'Expecting no die message' );
is( $getopts->option1, 5,        'correct default value' );

local @ARGV = ( '--option1', '8' );
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->add_option( spec => 'option1=i', default => 5, );
};
is( $trap->leaveby, 'return', 'adding an empty option failed' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on object with spec okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );
trap {
    $getopts->option1;
};
is( $trap->leaveby,    'return', 'calling option' );
is( $trap->stdout,     '',       'Expecting no STDOUT' );
is( $trap->stderr,     '',       'Expecting no STDERR' );
is( $trap->die,        undef,    'Expecting no die message' );
is( $getopts->option1, 8,        'default value overridden' );

@ARGV    = ( '--option1', '--option2', 'string', '--option3', '10' );
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->add_option( spec => 'hidden', hidden => 1, no_acessor => 1, );
};
is( $trap->leaveby, 'return', 'adding an empty option failed' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->add_option( spec => 'option1', help => 'help for 1' );
};
is( $trap->leaveby, 'return', 'adding an empty option failed' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->add_option( spec => 'option2|o=s', help => 'help for 2' );
};
is( $trap->leaveby, 'return', 'adding option2 failed' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->add_option(
        spec    => 'option3|alt_opt|O=i',
        help    => 'help for 3',
        default => 5
    );
};
is( $trap->leaveby, 'return', 'adding option3 failed' );
is( $trap->die,     undef,    'no error when spec provided' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on object with spec okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );
trap {
    $getopts->option1;
};
is( $trap->leaveby,    'return', 'calling option1' );
is( $trap->stdout,     '',       'Expecting no STDOUT' );
is( $trap->stderr,     '',       'Expecting no STDERR' );
is( $trap->die,        undef,    'Expecting no die message' );
is( $getopts->option1, 1,        'option1 is as expected' );
trap {
    $getopts->option1;
};
is( $trap->leaveby,    'return', 'calling option2' );
is( $trap->stdout,     '',       'Expecting no STDOUT' );
is( $trap->stderr,     '',       'Expecting no STDERR' );
is( $trap->die,        undef,    'Expecting no die message' );
is( $getopts->option2, 'string', 'option2 is as expected' );
trap {
    $getopts->option3;
};
is( $trap->leaveby,    'return', 'calling option3' );
is( $trap->stdout,     '',       'Expecting no STDOUT' );
is( $trap->stderr,     '',       'Expecting no STDERR' );
is( $trap->die,        undef,    'Expecting no die message' );
is( $getopts->option3, 10,       'option3 is as expected' );

$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->add_common_ssh_options;
};
is( $trap->leaveby, 'return', 'calling option2' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on object with spec okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );

$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->add_common_session_options;
};
is( $trap->leaveby, 'return', 'calling option2' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'return', 'getops on object with spec okay' );
is( $trap->stdout,  '',       'Expecting no STDOUT' );
is( $trap->stderr,  '',       'Expecting no STDERR' );
is( $trap->die,     undef,    'Expecting no die message' );

my $pod;
@ARGV    = ('--generate-pod');
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
$getopts->add_option(
    spec    => 'long_opt|l=s',
    help    => 'long opt help',
    default => 'default string'
);
$getopts->add_option( spec => 'another_long_opt|n=i', );
$getopts->add_option( spec => 'a=s',  help => 'short option only', );
$getopts->add_option( spec => 'long', help => 'long option only', );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'exit', 'adding an empty option failed' );
is( $trap->die,     undef,  'no error when spec provided' );
ok( defined( $trap->stdout ), 'Expecting no STDOUT' );
$pod = $trap->stdout;

# run pod through a checker at some point as it should be 'clean'
is( $trap->stderr, '',    'Expecting no STDERR' );
is( $trap->die,    undef, 'Expecting no die message' );

@ARGV    = ('--help');
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'exit', 'adding an empty option failed' );
is( $trap->die,     undef,  'no error when spec provided' );
ok( defined( $trap->stdout ), 'Expecting no STDOUT' );
is( $trap->stderr, '',    'Expecting no STDERR' );
is( $trap->die,    undef, 'Expecting no die message' );

@ARGV    = ('-?');
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'exit', 'adding an empty option failed' );
is( $trap->die,     undef,  'no error when spec provided' );
ok( defined( $trap->stdout ), 'Expecting no STDOUT' );
is( $trap->stderr, '',    'Expecting no STDERR' );
is( $trap->die,    undef, 'Expecting no die message' );

@ARGV    = ('-v');
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'exit', 'version option exist okay' );
is( $trap->die,     undef,  'no error when spec provided' );
like( $trap->stdout, qr/^Version: /, 'Version string correct' );
is( $trap->stderr, '',    'Expecting no STDERR' );
is( $trap->die,    undef, 'Expecting no die message' );

@ARGV    = ('-@');
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object );
trap {
    $getopts->getopts;
};
is( $trap->leaveby, 'exit', 'adding an empty option failed' );
is( $trap->die,     undef,  'no error when spec provided' );
ok( defined( $trap->stdout ), 'Expecting no STDOUT' );
like( $trap->stderr, qr{Unknown option: @}, 'Expecting no STDERR' );
is( $trap->die, undef, 'Expecting no die message' );

# test some common options
@ARGV = (
    '--unique-servers', '--title',    'title',  '-p',
    '22',               '--autoquit', '--tile', '--autoclose',
    '10',
);
$mock_object->{auto_close}        = 0;
$mock_object->{auto_quit}         = 0;
$mock_object->{window_tiling}     = 0;
$mock_object->{show_history}      = 0;
$mock_object->{use_all_a_records} = 1;
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object, );
trap {
    $getopts->getopts;
};
is( $trap->leaveby,             'return', 'adding an empty option failed' );
is( $trap->die,                 undef,    'no error when spec provided' );
is( $trap->stdout,              '',       'Expecting no STDOUT' );
is( $trap->stderr,              '',       'Expecting no STDERR' );
is( $trap->die,                 undef,    'Expecting no die message' );
is( $mock_object->{auto_close}, 10,       'auto_close set right' );
is( $mock_object->{auto_quit},  1,        'auto_quit set right' );
is( $mock_object->{window_tiling},     1, 'window_tiling set right' );
is( $mock_object->{show_history},      0, 'show_history set right' );
is( $mock_object->{use_all_a_records}, 1, 'use_all_a_records set right' );

@ARGV = (
    '--unique-servers', '--title',        'title', '-p', '22', '--autoquit',
    '--tile',           '--show-history', '-A',
);
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object, );
trap {
    $getopts->getopts;
};
is( $trap->leaveby,             'return', 'adding an empty option failed' );
is( $trap->die,                 undef,    'no error when spec provided' );
is( $trap->stdout,              '',       'Expecting no STDOUT' );
is( $trap->stderr,              '',       'Expecting no STDERR' );
is( $trap->die,                 undef,    'Expecting no die message' );
is( $mock_object->{auto_close}, 10,       'auto_close set right' );
is( $mock_object->{auto_quit},  0,        'auto_quit set right' );
is( $mock_object->{window_tiling},     0, 'window_tiling set right' );
is( $mock_object->{show_history},      1, 'show_history set right' );
is( $mock_object->{use_all_a_records}, 0, 'use_all_a_records set right' );

TODO: {
    local $TODO = "explitely test for duplicate options";
    $getopts = App::ClusterSSH::Getopt->new(
        parent => Test::ClusterSSH::Mock->new() );
    trap {
        $getopts->add_option( spec => 'option1' );
    };
    is( $trap->leaveby, 'return', 'adding an empty option failed' );
    is( $trap->die,     undef,    'no error when spec provided' );
    is( $trap->stdout,  '',       'Expecting no STDOUT' );
    is( $trap->stderr,  '',       'Expecting no STDERR' );
    trap {
        $getopts->add_option( spec => 'option1' );
    };
    is( $trap->leaveby, 'die',         'adding an empty option failed' );
    is( $trap->die,     "bling bling", 'no error when spec provided' );
    is( $trap->stdout,  'bling bling', 'Expecting no STDOUT' );
    is( $trap->stderr,  'bling bling', 'Expecting no STDERR' );
    trap {
        $getopts->getopts;
    };
    is( $trap->leaveby, 'return', 'getops on object with spec okay' );
    is( $trap->stdout,  '',       'Expecting no STDOUT' );
    is( $trap->stderr,  '',       'Expecting no STDERR' );
    is( $trap->die,     undef,    'Expecting no die message' );
}

@ARGV    = ( '--rows', 5, '--cols', 10 );
$getopts = App::ClusterSSH::Getopt->new( parent => $mock_object, );
trap {
    $getopts->getopts;
};

$trap->did_return(" ... returned");
$trap->quiet(" ... quietly");
is( $mock_object->{cols}, 10, 'cols set correctly' );
is( $mock_object->{rows}, 5,  'rows set correctly' );

done_testing;
