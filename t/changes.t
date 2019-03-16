use Test::More;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

eval 'use Test::CPAN::Changes';
plan skip_all => 'Test::CPAN::Changes required for this test' if $@;
changes_ok();
