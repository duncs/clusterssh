use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    meta_merge => { 
        resources => { 
            repository => [
                'http://clusterssh.git.sourceforge.net/',
                'http://github.com/duncs/clusterssh', 
            ],
        }, 
    },
    module_name => 'App::ClusterSSH',
    license     => 'perl',
    requires    => {
        'version'       => '0',
        'Tk'            => '800.022',
        'X11::Protocol' => '0.56',
    },
    build_requires => {
        'Test::Pod::Coverage' => 0,
        'Test::Pod'           => 0,
    },
    script_files   => 'bin',
);

$build->create_build_script;
