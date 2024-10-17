#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;
use Test::Trap;
use Data::Dump;

require_ok('App::ClusterSSH::Range')
    || BAIL_OUT('Failed to use App::ClusterSSH::Range');

my %tests = (
    'a'                   => 'a',
    'c{a,b}'              => 'ca cb',
    'd{a,b,c}'            => 'da db dc',
    'e{0}'                => 'e0',
    'f{0..3}'             => 'f0 f1 f2 f3',
    'g{0..2,4}'           => 'g0 g1 g2 g4',
    'h{0..2,4..6}'        => 'h0 h1 h2 h4 h5 h6',
    'i{0..1,a}'           => 'i0 i1 ia',
    'j{0..2,a,b,c}'       => 'j0 j1 j2 ja jb jc',
    'k{4..6,a..c}'        => 'k4 k5 k6 ka kb kc',
    'l{0..2,7..9,e..g}'   => 'l0 l1 l2 l7 l8 l9 le lf lg',
    'm{0,1}'              => 'm0 m1',
    'n0..2}'              => 'n0..2}',
    'host{a,b}-test{1,2}' =>
        'hosta-test1 hosta-test2 hostb-test1 hostb-test2',

    # NOTE: the following are not "as expected" in line with above tests
    # due to bsd_glob functionality.  See output from:
    #    print join(q{ }, bsd_glob("o{a,b,c")).$/
    'o{a,b,c' => 'o',
    'p{0..2'  => 'p',

    # Reported as bug in github issue #89
    'q-0{0,1}'  => 'q-00 q-01',
    'q-0{0..1}' => 'q-00 q-01',

    # expand pure ranges
    '{10..12}' => '10 11 12',

    # expand ports
    'lh:{22001..22003}' => 'lh:22001 lh:22002 lh:22003',

    # FQDN's
    'lh{1..3}.dot.com' => 'lh1.dot.com lh2.dot.com lh3.dot.com',

    # IP addresses
    '127.0.0.{10..12}' => '127.0.0.10 127.0.0.11 127.0.0.12',
    '127.0.{20..22}.1' => '127.0.20.1 127.0.21.1 127.0.22.1',
);

my $range = App::ClusterSSH::Range->new();
isa_ok( $range, 'App::ClusterSSH::Range', 'object created correctly' );

for my $key ( sort keys %tests ) {
    my $expected = $tests{$key};
    my @expected = split / /, $tests{$key};

    my $got;
    trap {
        $got = $range->expand($key);
    };

    is( $trap->stdout,  '',          "No stdout for scalar $key" );
    is( $trap->stderr,  '',          "No stderr for scalar $key" );
    is( $trap->leaveby, 'return',    "correct leaveby for scalar $key" );
    is( $trap->die,     undef,       "die is undef for scalar $key" );
    is( $got,           "$expected", "expected return for scalar $key" );

    my @got;
    trap {
        @got = $range->expand($key);
    };

    is( $trap->stdout,  '',       "No stdout for array $key" );
    is( $trap->stderr,  '',       "No stderr for array $key" );
    is( $trap->leaveby, 'return', "correct leaveby for array $key" );
    is( $trap->die,     undef,    "die is undef for array $key" );
    is_deeply( \@got, \@expected, "expected return for array $key" )
        || diag explain \@got;
}

done_testing();
