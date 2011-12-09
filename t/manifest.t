use Test::More;

# This is the common idiom for author test modules like this, but see
# the full example in examples/checkmanifest.t and, more importantly,
# Adam Kennedy's article: http://use.perl.org/~Alias/journal/38822
eval 'use Test::DistManifest';
if ($@) {
    plan skip_all => 'Test::DistManifest required to test MANIFEST';
}

manifest_ok( 'MANIFEST', 'MANIFEST.SKIP' );
