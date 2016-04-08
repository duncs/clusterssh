package App::ClusterSSH::Window;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;

use base qw/ App::ClusterSSH::Base /;

sub new {

    my $package = __PACKAGE__.'::Tk';

    require $package;
    $package->import();

}



1;
