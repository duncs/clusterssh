package App::ClusterSSH::Window;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;

use base qw/ App::ClusterSSH::Base /;

# Module to contain window generic code and pull in specific code from
# an appropriate module

sub import {
    my ($class) = @_;

    # Find what windows module we should be using and just overlay it into
    # this object
    my $package_name = __PACKAGE__ . '::Tk';
    ( my $package_path = $package_name ) =~ s{::}{/}g;
    require "$package_path.pm";
    $package_name->import();

    {
        no strict 'refs';
        push @{ __PACKAGE__ . '::ISA' }, $package_name;
    }
}

my %servers;

sub new {
    my ( $class, %args ) = @_;
    my $self = $class->SUPER::new(%args);

    return $self;
}

1;
