use strict;
use warnings;

use FindBin qw($Bin $Script);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use File::Which qw(which);
use File::Temp qw(tempdir);
use English '-no_match_vars';

use Readonly;

BEGIN {
    use_ok("App::ClusterSSH::Cluster") || BAIL_OUT('failed to use module');
}

my $cluster1 = App::ClusterSSH::Cluster->new();
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

@default_expected = sort 
    qw/ default people tag1 tag2 tag3 tag10 tag20 tag30 tag40 tag50 /;
trap {
    @default = $cluster1->list_tags;
};
is($trap->leaveby, 'return', 'list_tags returned okay');
is( $trap->stdout,  '',       'no stdout for non-existant get_tag' );
is( $trap->stderr,  '',       'no stderr for non-existant get_tag' );
is_deeply( \@default, \@default_expected, 'tag list correct' );

my $count;
trap {
    $count = $cluster1->list_tags;
};
is($trap->leaveby, 'return', 'list_tags returned okay');
is( $trap->stdout,  '',       'no stdout for non-existant get_tag' );
is( $trap->stderr,  '',       'no stderr for non-existant get_tag' );
is_deeply( $count, 10, 'tag list count correct' );

# now checks against running an external command

my @external_expected;

@external_expected
    = $cluster1->get_external_clusters("$Bin/external_cluster_command");
is_deeply( \@external_expected, [], 'External command no args' );

@external_expected = $cluster1->get_external_clusters(
    "$Bin/external_cluster_command tag1 tag2");
is_deeply( \@external_expected, [qw/tag1 tag2 /],
    'External command: 2 args passed through' );

@external_expected = $cluster1->get_external_clusters(
    "$Bin/external_cluster_command tag100");
is_deeply( \@external_expected, [qw/host100 /],
    'External command: 1 tag expanded to one host' );

@external_expected = $cluster1->get_external_clusters(
    "$Bin/external_cluster_command tag200");
is_deeply(
    \@external_expected,
    [qw/host200 host205 host210 /],
    'External command: 1 tag expanded to 3 hosts and sorted'
);

@external_expected = $cluster1->get_external_clusters(
    "$Bin/external_cluster_command tag400");
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
    @external_expected = $cluster1->get_external_clusters(
        "$Bin/external_cluster_command -x $redirect");
};
like(
    $trap->die,
    qr/External command failure.*external_cluster_command.*Return Code: 5/ms,
    'External command: caught exception message'
);
is( $trap->stdout, '', 'External command: no stdout from perl code' );
is( $trap->stderr, '', 'External command: no stderr from perl code' );

trap {
    @external_expected = $cluster1->get_external_clusters(
        "$Bin/external_cluster_command -q $redirect");
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
