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

use Readonly;

BEGIN { use_ok("App::ClusterSSH") }

my $app;

$app = App::ClusterSSH->new();
isa_ok( $app,         'App::ClusterSSH' );
isa_ok( $app->config, 'App::ClusterSSH::Config' );

done_testing();
