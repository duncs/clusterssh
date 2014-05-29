use strict;
use warnings;
use Cwd;

use Module::Build;

my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code  => q{
        use File::Slurp;

        sub ACTION_email {
            my ($self, @args) = @_;

            # Make sure all tests pass first
            $self->depends_on("test");

            print "Use '--changes <N>' to define how many to output.  Default: 1", $/;
            my $change_count = $self->args('changes') || 1;

            use CPAN::Changes;
            my @changes = CPAN::Changes->load( 'Changes' )->releases;

            if($changes[-1]->date =~ m/^0000/) {
                die '#' x 40, $/, ' ' x 3, "FATAL: 'Changes' date not updated",$/,'#' x 40, $/;
            }

            print $/;

            foreach my $change ( 1 .. $change_count ) {
                print $changes[ 0 - $change]->serialize;
            }

            my $v=$self->dist_version;

            print <<"EOF";
==========
Bug Reports and Issues: https://github.com/duncs/clusterssh/issues
Project Repository: http://github.com/duncs/clusterssh
CPAN release: http://search.cpan.org/~duncs/App-ClusterSSH-$v
SF release: http://sourceforge.net/projects/clusterssh/files/2.%20ClusterSSH%20Series%204/App-ClusterSSH-${v}.tar.gz/download
SF/net git repo: https://sourceforge.net/scm/?type=git&group_id=89139
==========
EOF
            return $self;
        }

        sub ACTION_build {
            my ($self, @args) = @_;

            print "Building pod files",$/;

#            my $common_file = File::Slurp::read_file('pod_data/common_file');
#            die "Failed to read 'pod_data/common_file'" unless($common_file);

            # Each file in bin/ should have a file within pod_data.
            # If not, there is a problem.
            my @files=glob('bin/*');
            foreach my $binfile (@files) {
                # ignore any dirs or such in the bin directory
                next unless(-f $binfile && -x $binfile);

#                (my $podfile = $binfile) =~ s!bin!pod_data!;
#                warn "checking $podfile",$/;
#
#                if(!-f $podfile) {
#                    warn "$podfile does not exist",$/;
#                    next;
#                }
#                my $pod = read_file( $podfile );
#                warn "Unable to read '$podfile'" unless ($pod);
#
#                $pod =~ s/%FILES%/$common_file/;
#
#                my $options = qx{ $binfile -h 2>&1 };
#                warn "Unable to run '$binfile -h'" unless ($options);

                my $cmd="$binfile --generate-pod 2>&1";
                warn "Running: $cmd",$/;
                my $pod = qx { $cmd };
                die "Failed to generate POD" if($?);
                write_file("${binfile}.pod", $pod);

            }

            $self->SUPER::ACTION_build;
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
        'CPAN::Changes'       => 0.27,
        'File::Slurp'         => 0,
    },
    configure_requires => { 'Module::Build' => 0, },
    add_to_cleanup     => ['App-ClusterSSH-*'],
    create_makefile_pl => 'traditional',
    script_files       => 'bin',
    get_options => { changes => { type => '=s' }, },
);

$build->create_build_script;
