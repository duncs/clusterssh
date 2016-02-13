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
use File::Temp qw(tempdir);
use English '-no_match_vars';

use Readonly;

package Test::ClusterSSH::Mock;

# generate purpose object used to simplfy testing

sub new {
    my ( $class, %args ) = @_;
    my $config = {%args};
    return bless $config, $class;
}

sub parent {
    my ($self) = @_;
    return $self;
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

BEGIN {
    use_ok("App::ClusterSSH::Cluster") || BAIL_OUT('failed to use module');
}

my $mock_object = Test::ClusterSSH::Mock->new(
    shell_expansion => "/bin/bash -c 'shopt -s extglob\n echo %items%'", );

my $cluster1 = App::ClusterSSH::Cluster->new( parent => $mock_object );
isa_ok( $cluster1, 'App::ClusterSSH::Cluster' );

my $cluster2 = App::ClusterSSH::Cluster->new();
isa_ok( $cluster2, 'App::ClusterSSH::Cluster' );

my %expected = ( people => [ 'fred', 'jo', 'pete', ] );

$cluster1->register_tag( 'people', @{ $expected{people} } );

my @got = $cluster2->get_tag('people');
is_deeply( \@got, \@{ $expected{people} }, 'Shared cluster object' )
    or diag explain @got;
my %got = $cluster2->dump_tags;

is_deeply( \%got, \%expected, 'Shared cluster object' ) or diag explain %got;

# should pass without issue
trap {
    $cluster1->read_cluster_file( $Bin . '/30cluster.doesnt exist' );
};
is( !$trap, '', 'coped with missing file ok' );
isa_ok( $cluster1, 'App::ClusterSSH::Cluster' );

# no point running this test as root since root cannot be blocked
# from accessing the file
if ( $EUID != 0 ) {
    my $no_read = $Bin . '/30cluster.cannot_read';
    chmod 0000, $no_read;
    trap {
        $cluster1->read_cluster_file($no_read);
    };
    chmod 0644, $no_read;
    isa_ok( $trap->die, 'App::ClusterSSH::Exception::LoadFile' );
    is( $trap->die,
        "Unable to read file $no_read: Permission denied",
        'Error on reading an existing file ok'
    );
}
else {
    pass('Cannot test for lack of read access when run as root');
}

$expected{tag1} = ['host1'];
$cluster1->read_cluster_file( $Bin . '/30cluster.file1' );
test_expected( 'file 1', %expected );

$expected{tag2} = [ 'host2', ];
$expected{tag3} = [ 'host3', 'host4' ];
$cluster1->read_cluster_file( $Bin . '/30cluster.file2' );
test_expected( 'file 2', %expected );

$expected{tag10} = [ 'host10', 'host20', 'host30' ];
$expected{tag20} = [ 'host10', ];
$expected{tag30} = [ 'host10', ];
$expected{tag40} = [ 'host20', 'host30', ];
$expected{tag50} = [ 'host30', ];
$cluster1->read_tag_file( $Bin . '/30cluster.tag1' );
test_expected( 'tag 1', %expected );

$cluster1->read_cluster_file( $Bin . '/30cluster.file3' );
my @default_expected = (qw/ host7 host8 host9 /);
$expected{default} = \@default_expected;
test_expected( 'file 3', %expected );
my @default = $cluster1->get_tag('default');
is_deeply( \@default, \@default_expected, 'default cluster ok' );

is( scalar $cluster1->get_tag('default'),
    scalar @default_expected,
    'Count correct'
);

my $tags;
trap {
    $tags = $cluster1->get_tag('does_not_exist');
};
is( $trap->leaveby, 'return', 'non-existant tag returns correctly' );
is( $trap->stdout,  '',       'no stdout for non-existant get_tag' );
is( $trap->stderr,  '',       'no stderr for non-existant get_tag' );
is( $tags,          undef,    'non-existant tag returns undef' );

@default_expected
    = sort qw/ default people tag1 tag2 tag3 tag10 tag20 tag30 tag40 tag50 /;
trap {
    @default = $cluster1->list_tags;
};
is( $trap->leaveby, 'return', 'list_tags returned okay' );
is( $trap->stdout,  '',       'no stdout for non-existant get_tag' );
is( $trap->stderr,  '',       'no stderr for non-existant get_tag' );
is_deeply( \@default, \@default_expected, 'tag list correct' );

my $count;
trap {
    $count = $cluster1->list_tags;
};
is( $trap->leaveby, 'return', 'list_tags returned okay' );
is( $trap->stdout,  '',       'no stdout for non-existant get_tag' );
is( $trap->stderr,  '',       'no stderr for non-existant get_tag' );
is_deeply( $count, 10, 'tag list count correct' );

# now checks against running an external command

my @external_expected;

# text fetching external clusters when no command set or runnable
#$mock_object->{external_cluster_command} = '/tmp/doesnt_exist';
trap {
    @external_expected = $cluster1->_run_external_clusters();
};
is( $trap->leaveby, 'return', 'non-existant tag returns correctly' );
is( $trap->stdout,  '',       'no stdout for non-existant get_tag' );
is( $trap->stderr,  '',       'no stderr for non-existant get_tag' );
is( $tags,          undef,    'non-existant tag returns undef' );
@external_expected = $cluster1->list_external_clusters();
is_deeply( \@external_expected, [], 'External command doesnt exist' );
is( scalar $cluster1->list_external_clusters,
    0, 'External command failed tag count' );

$mock_object->{external_cluster_command} = "$Bin/external_cluster_command";

@external_expected = $cluster1->list_external_clusters();
is_deeply(
    \@external_expected,
    [qw/ tag100 tag200 tag300 tag400 /],
    'External command no args'
);
is( scalar $cluster1->list_external_clusters,
    4, 'External command tag count' );

@external_expected = $cluster1->get_external_clusters();
is_deeply( \@external_expected, [], 'External command no args' );

@external_expected = $cluster1->get_external_clusters("tag1 tag2");
is_deeply( \@external_expected, [qw/tag1 tag2 /],
    'External command: 2 args passed through' );

@external_expected = $cluster1->get_external_clusters("tag100");
is_deeply( \@external_expected, [qw/host100 /],
    'External command: 1 tag expanded to one host' );

@external_expected = $cluster1->get_external_clusters("tag200");
is_deeply(
    \@external_expected,
    [qw/host200 host205 host210 /],
    'External command: 1 tag expanded to 3 hosts and sorted'
);

@external_expected = $cluster1->get_external_clusters("tag400");
is_deeply(
    \@external_expected,
    [   qw/host100 host200 host205 host210 host300 host325 host350 host400 host401 /
    ],
    'External command: 1 tag expanded with self referencing tags'
);

# NOTE
# Since this is calling a shell run command, the tests cannot capture
# the shell STDOUT and STDERR.  By default redirect STDOUT and STDERR into
# /dev/null so it dones't make noise in normal test output
# However, don't hide it if running with -v flag
my $redirect = ' 1>/dev/null 2>&1';
if ( $ENV{TEST_VERBOSE} ) {
    $redirect = '';
}

trap {
    @external_expected = $cluster1->get_external_clusters("-x $redirect");
};
like(
    $trap->die,
    qr/External command failure.*external_cluster_command.*Return Code: 5/ms,
    'External command: caught exception message'
);
is( $trap->stdout, '', 'External command: no stdout from perl code' );
is( $trap->stderr, '', 'External command: no stderr from perl code' );

trap {
    @external_expected = $cluster1->get_external_clusters("-q $redirect");
};
like(
    $trap->die,
    qr/External command failure.*external_cluster_command.*Return Code: 255/ms,
    'External command: caught exception message'
);
is( $trap->stdout, '', 'External command: no stdout from perl code' );
is( $trap->stderr, '', 'External command: no stderr from perl code' );

# check reading of cluster files
trap {
    $cluster1->get_cluster_entries( $Bin . '/30cluster.file3' );
};
is( $trap->leaveby, 'return', 'exit okay on get_cluster_entries' );
is( $trap->stdout,  '',       'no stdout for get_cluster_entries' );
is( $trap->stderr,  '',       'no stderr for get_cluster_entries' );

# check reading of tag files
trap {
    $cluster1->get_tag_entries( $Bin . '/30cluster.tag1' );
};
is( $trap->leaveby, 'return', 'exit okay on get_tag_entries' );
is( $trap->stdout,  '',       'no stdout for get_tag_entries' );
is( $trap->stderr,  '',       'no stderr for get_tag_entries' );

# test bash expansion
my @expected = ( 'aa', 'ab', 'ac' );
$cluster1->register_tag( 'glob1', 'a{a,b,c}' );
@got = $cluster2->get_tag('glob1');
is_deeply( \@got, \@expected, 'glob1 expansion, words' )
    or diag explain @got;

@expected = ( 'ax', 'ay', 'az' );
$cluster1->register_tag( 'glob2', 'a{x..z}' );
@got = $cluster2->get_tag('glob2');
is_deeply( \@got, \@expected, 'glob2 expansion, words' )
    or diag explain @got;

@expected = ( 'b1', 'b2', 'b3' );
$cluster1->register_tag( 'glob3', 'b{1..3}' );
@got = $cluster2->get_tag('glob3');
is_deeply( \@got, \@expected, 'glob3 expansion, number range' )
    or diag explain @got;

@expected = ( 'ca', 'cb', 'cc', 'd7', 'd8', 'd9' );
$cluster1->register_tag( 'glob4', 'c{a..c}', 'd{7..9}' );
@got = $cluster2->get_tag('glob4');
is_deeply( \@got, \@expected, 'glob4 expansion, mixed' )
    or diag explain @got;

# make sure reasonable expansions get through with no nasty metachars
@expected = ( 'cd..f}', 'c{a..c' );
$cluster1->register_tag( 'glob5', 'c{a..c', 'cd..f}' );
@got = $cluster2->get_tag('glob5');
is_deeply( \@got, \@expected, 'glob5 expansion, mixed' )
    or diag explain @got;

@expected = ();
trap {
    $cluster1->register_tag( 'glob6', 'c{a..c} ; echo NASTY' );
};
is( $trap->leaveby, 'return', 'didnt die on nasty chars' );
is( $trap->die,     undef,    'didnt die on nasty chars' );
is( $trap->stdout,  q{},      'Expecting no STDOUT' );
like(
    $trap->stderr,
    qr/Bad characters picked up in tag 'glob6':.*/,
    'warned on nasty chars'
);
@got = $cluster2->get_tag('glob6');
is_deeply( \@got, \@expected, 'glob6 expansion, nasty chars' )
    or diag explain @got;

@expected = ();
trap {
    $cluster1->register_tag( 'glob7', 'c{a..b} `echo NASTY`' );
};
is( $trap->leaveby, 'return', 'didnt die on nasty chars' );
is( $trap->die,     undef,    'didnt die on nasty chars' );
is( $trap->stdout,  q{},      'Expecting no STDOUT' );
like(
    $trap->stderr,
    qr/Bad characters picked up in tag 'glob7':.*/,
    'warned on nasty chars'
);
@got = $cluster2->get_tag('glob7');
is_deeply( \@got, \@expected, 'glob7 expansion, nasty chars' )
    or diag explain @got;

@expected = ();
trap {
    $cluster1->register_tag( 'glob8', 'c{a..b} $!', );
};
is( $trap->leaveby, 'return', 'didnt die on nasty chars' );
is( $trap->die,     undef,    'didnt die on nasty chars' );
is( $trap->stdout,  q{},      'Expecting no STDOUT' );
like(
    $trap->stderr,
    qr/Bad characters picked up in tag 'glob8':.*/,
    'warned on nasty chars'
);
@got = $cluster2->get_tag('glob8');
is_deeply( \@got, \@expected, 'glob8 expansion, nasty chars' )
    or diag explain @got;

done_testing();

sub test_expected {
    my ( $test, %expected ) = @_;

    foreach my $key ( keys %expected ) {
        my @got = $cluster2->get_tag($key);
        is_deeply(
            \@got,
            \@{ $expected{$key} },
            'file ' . $test . ' get_tag on: ' . $key
        ) or diag explain @got;
    }

    my %got = $cluster1->dump_tags;
    is_deeply( \%got, \%expected, 'file ' . $test . ' dump_tags' )
        or diag explain %got;
}
