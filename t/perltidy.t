#!perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

eval "use Test::PerlTidy";
plan skip_all => "Test::PerlTidy required for testing code" if $@;

# Please see t/perltidyrc for the authors normal perltidy options

run_tests(
    perltidyrc => $Bin . '/perltidyrc',
    exclude    => [ '_build/', 'blib/', 'Makefile.PL', ]
);
