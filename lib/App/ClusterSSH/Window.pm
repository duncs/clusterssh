use strict;
use warnings;

package App::ClusterSSH::Window;

# ABSTRACT: App::ClusterSSH::Window - Base obejct for different types of window module

=head1 DESCRIPTION

Base object to allow for configuring and using different types of windows libraries

=cut

=head1 METHODS

=over 4

=cut

use Carp;

use base qw/ App::ClusterSSH::Base /;

# Module to contain window generic code and pull in specific code from
# an appropriate module

sub import {
    my ($class) = @_;

    # If we are building or in test here, just exit
    # as travis build servers will not have Tk installed
    return if $ENV{AUTHOR_TESTING} || $ENV{RELEASE_TESTING};

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

=item $obj = App::ClusterSSH::Window->new({});

Creates object

=back

=cut

sub new {
    my ( $class, %args ) = @_;
    my $self = $class->SUPER::new(%args);

    return $self;
}

1;
