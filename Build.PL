use strict;
use warnings;
use Cwd;

use Module::Build;

my %project_info = (
    tracker    => 'https://github.com/duncs/clusterssh/issues',
    repository => 'http://github.com/duncs/clusterssh',
    homepage   => 'http://github.com/duncs/clusterssh/wiki',
);

my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code  => qq{
        my \%project_info = ( 
            tracker => '$project_info{tracker}', 
            homepage => '$project_info{homepage}',
            repository => '$project_info{repository}',
        );
    } . q{
    # don't check for errors; 'build_requires' should get this sorted
    eval {
        require File::Slurp;
        require CPAN::Changes;
    };

        sub ACTION_email {
            my ($self, @args) = @_;

            # Make sure all tests pass first
            $self->depends_on("test");

            print "Use '--changes <N>' to define how many to output.  Default: 1", $/;
            my $change_count = $self->args('changes') || 1;

            my @changes = CPAN::Changes->load( 'Changes' )->releases;

            if($changes[-1]->date =~ m/^0000/) {
                die '#' x 40, $/, ' ' x 3, "FATAL: 'Changes' date not updated",$/,'#' x 40, $/;
            }

            print $/;
            print 'Subject: ClusterSSH ', $self->dist_version, ' release', $/;
            print $/;

            foreach my $change ( 1 .. $change_count ) {
                print $changes[ 0 - $change]->serialize;
            }

            my $v=$self->dist_version;

            print <<"EOF";
==========
Home page: $project_info{homepage},
Bug Reports and Issues: $project_info{tracker}
Project Repository: $project_info{repository}
CPAN release: http://search.cpan.org/~duncs/App-ClusterSSH-$v
SF release: http://sourceforge.net/projects/clusterssh/files/2.%20ClusterSSH%20Series%204/App-ClusterSSH-${v}.tar.gz/download
==========
EOF
            return $self;
        }
    },
);

my $build = $class->new(
    meta_merge => {
        resources => {
            Repository => [
                'http://clusterssh.git.sourceforge.net/',
                $project_info{repository},
            ],
            bugtracker => $project_info{tracker},
            homepage   => $project_info{homepage},
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
        'Getopt::Long'     => 0,
        'File::Path'       => 0,
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
        'CPAN::Changes'       => 0.27,
        'File::Slurp'         => 0,
        'Test::PerlTidy'      => 0,
    },
    recommends         => { 'Sort::Naturally' => 0, },
    configure_requires => { 'Module::Build'   => 0, },
    add_to_cleanup     => ['App-ClusterSSH-*'],
    create_makefile_pl => 'traditional',
    script_files       => 'bin',
    get_options => { changes              => { type => '=s' }, },
    PL_files    => { 'bin_PL/_build_docs' => [], },
);

$build->create_build_script;
