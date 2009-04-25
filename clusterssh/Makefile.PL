# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name 'ClusterSSH';
all_from 'lib/ClusterSSH.pm';

# Specific dependencies
requires 'Tk'            => 0;
requires 'X11::Protocol' => '0';
requires 'version'       => '0';
requires 'Readonly'      => '0';

test_requires 'Test::More'         => '0.42';
test_requires 'Test::Perl::Critic' => '0';
test_requires 'Test::PerlTidy'     => '0';
test_requires 'Test::Trap'         => '0.2.0';
test_requires 'Test::Exception'    => '0.27';

build_requires 'Module::Install' => '0.82';

#no_index        'directory'         => 'demos';

install_script 'bin/cssh';
install_script 'bin/cscp';
install_script 'bin/ctel';
install_script 'bin/crsh';

#auto_install;
WriteAll;
