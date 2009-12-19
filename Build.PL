use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name  => 'App::ClusterSSH',
    license      => 'gpl',
    requires     => {
        'version'  => '0',
    },
    build_requires => {
    },
    script_files => 'bin',
);

$build->create_build_script;
