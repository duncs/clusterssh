package App::ClusterSSH::L10N;

use strict;
use warnings;

use Locale::Maketext 1.01;
use base qw(Locale::Maketext);

# This projects primary language is English

our %Lexicon = ( '_AUTO' => 1, );

1;

=pod

=head1 

ClusterSSH::L10N - Base translations module

=head1 SYNOPSIS

    use ClusterSSH::L10N;
    my $lang = ClusterSSH::L10N->get_handle('en');
    $lang->maketext('text to localise with args [_1]', $arg1);

=head1 DESCRIPTION

L<Locale::Maketext> based translation module for ClusterSSH. See 
L<Locale::Maketext> for more information and usage.

NOTE: the default language of this module is English.

=head1 METHODS

See Locale::Maketext - there are curently no extra methods in this module.

=head1 AUTHOR

Duncan Ferguson (<duncan_j_ferguson (at) yahoo.co.uk>)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009 Duncan Ferguson (<duncan_j_ferguson (at) yahoo.co.uk>). 
All rights reserved

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
