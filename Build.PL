use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name  => 'App::ClusterSSH',
    license      => 'perl',
    requires     => {
        'version'       => '0',
        'Tk'            => '800.022',
        'X11::Protocol' => '0.56',
    },
    build_requires => {
    },
    script_files => 'bin',
);

$build->create_build_script;
