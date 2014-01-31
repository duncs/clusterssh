use strict;
use warnings;

use Module::Build;

my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code  => q{
        sub ACTION_email {
            my ($self, @args) = shift;

            my $v=$self->dist_version;

            print $/, '=' x 10,$/,$/;
            print 'Bug Reports and Issues: https://github.com/duncs/clusterssh/issues',$/;
            print 'Project Repository: http://github.com/duncs/clusterssh',$/;
            print 'CPAN release: http://search.cpan.org/~duncs/App-ClusterSSH-',$v,$/;
            print 'SF release: http://sourceforge.net/projects/clusterssh/files/2.%20ClusterSSH%20Series%204/App-ClusterSSH-',$v,'.tar.gz/download',$/;
            print 'SF/net git repo: https://sourceforge.net/scm/?type=git&group_id=89139',$/;
            print $/, '=' x 10,$/,$/;
        }
    },
);

my $build = $class->new(
    meta_merge => {
        resources => {
            Repository => [
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
        'Exception::Class' => '1.31',
        'Try::Tiny'        => 0,
    },
    build_requires => {
        'Test::Pod::Coverage' => 0,
        'Test::Pod'           => 0,
        'Test::Trap'          => 0,
        'Readonly'            => 0,
        'File::Which'         => 0,
        'File::Temp'          => 0,
        'Test::DistManifest'  => 0,
        'Test::Differences'   => 0,
    },
    configure_requires => { 'Module::Build' => 0, },
    add_to_cleanup     => ['App-ClusterSSH-*'],
    create_makefile_pl => 'traditional',
    script_files       => 'bin',
);

$build->create_build_script;
