use lib 'inc';

require Module::Build;

my %module_build_args = (
    module_name   => 'App::ClusterSSH',
    dist_abstract => "Cluster administration tool",
##{ $plugin->get_prereqs(1) ##}
##{ $plugin->get_default('share_dir') ##}
    script_files => [
        'bin/cssh', 'bin/csftp',
        'bin/ccon', 'bin/crsh',
        'bin/ctel', 'bin/clusterssh_bash_completion.dist'
    ],
    PL_files => {
        'bin_PL/_build_docs' => [
            'bin/cssh', 'bin/csftp',
            'bin/ccon', 'bin/crsh',
            'bin/ctel', 'bin/clusterssh_bash_completion.dist'
        ],
    },
);

unless ( eval { Module::Build->VERSION(0.4004) } ) {
    my $tr = delete $module_build_args{test_requires};
    my $br = $module_build_args{build_requires};
    for my $mod ( keys %$tr ) {
        if ( exists $br->{$mod} ) {
            $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
        }
        else {
            $br->{$mod} = $tr->{$mod};
        }
    }
}    # end unless Module::Build is 0.4004 or newer

my $builder = Module::Build->new(%module_build_args);
$builder->create_build_script;
