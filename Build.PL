use strict;
use warnings;

use Module::Build;
my $build = Module::Build->new(
    module_name  => 'ClusterSSH',
    dist_version => '4.0.1',
    license      => 'gpl',
    requires     => {
        'version'  => '0',
        'Readonly' => '0',

        # 'Tk'            => 0,
        #' X11::Protocol' => '0',
    },
    build_requires => {
        'Devel::Cover'        => '0.42',
        'Test::More'          => '0.42',
        'Test::Perl::Critic'  => '0',
        'Test::PerlTidy'      => '0',
        'Test::Trap'          => '0.2.0',
        'Test::Exception'     => '0.27',
        'Test::Pod'           => '0',
        'Test::Pod::Coverage' => '0',
        'Test::Deep'          => '0',
        'Perl::Critic::Bangs' => '1.02',
    },
    script_files => 'bin',
);

$build->create_build_script;
