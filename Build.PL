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
            bugtracker => 'http://sourceforge.net/tracker/?group_id=89139',
            homepage   => 'http://clusterssh.sourceforge.net/',
        },
    },
    module_name       => 'App::ClusterSSH',
    license           => 'perl',
    dist_author       => q{Duncan Ferguson <duncan_j_ferguson@yahoo.co.uk>},
    dist_version_from => 'lib/App/ClusterSSH.pm',
    requires          => {
        'version'          => '0',
        'Tk'               => '800.022',
        'X11::Protocol'    => '0.56',
        'Locale::Maketext' => 0,
    },
    build_requires => {
        'Test::Pod::Coverage' => 0,
        'Test::Pod'           => 0,
        'Test::Trap'          => 0,
    },
    add_to_cleanup     => ['App-ClusterSSH-*'],
    create_makefile_pl => 'traditional',
    script_files       => 'bin',
);

$build->create_build_script;
