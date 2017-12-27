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

=pod

=head1 NAME

App::ClusterSSH::Window - Base obejct for different types of window module

=head1 DESCRIPTION

Base object to allow for configuring and using different types of windows libraries

=head1 METHODS

=over 4

=item $obj = App::ClusterSSH::Window->new({});

Creates object

=back

=head1 AUTHOR

Duncan Ferguson, C<< <duncan_j_ferguson at yahoo.co.uk> >>

=head1 LICENSE AND COPYRIGHT

Copyright 1999-2018 Duncan Ferguson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
