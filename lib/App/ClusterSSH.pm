package App::ClusterSSH;

use 5.008.004;
use warnings;
use strict;
use version; our $VERSION = version->new('4.00_02');

use Carp;

use base qw/ App::ClusterSSH::Base /;

use POSIX ":sys_wait_h";
use App::ClusterSSH::Gui;

# Notes on general order of processing
#
# parse cmd line options for extra config files
# load system configuration files
# load cfg files from options
# overlay rest of cmd line args onto options
# record all clusters
# parse givwen tags/hostnames and resolve to connections
# open terminals
# optionally open console if required

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

    # catch and reap any zombies
    $SIG{CHLD} = \&REAPER;

    $self->{gui} = App::ClusterSSH::Gui->new();

    return $self;
}

sub gui {
    my ($self) = @_;
    return $self->{gui};
}

sub REAPER {
    my $kid;
    do {
        $kid = waitpid( -1, WNOHANG );
        logmsg( 2, "REAPER currently returns: $kid" );
    } until ( $kid == -1 || $kid == 0 );
}

1;

__END__

=head1 NAME

App::ClusterSSH - The great new App::ClusterSSH!

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use App::ClusterSSH;

    my $foo = App::ClusterSSH->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 function1

=head2 function2

=head1 AUTHOR

Duncan Ferguson, C<< <duncan_j_ferguson at yahoo.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-clusterssh at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-ClusterSSH>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::ClusterSSH

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-ClusterSSH>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-ClusterSSH>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-ClusterSSH>

=item * Search CPAN

L<http://search.cpan.org/dist/App-ClusterSSH/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 Duncan Ferguson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

