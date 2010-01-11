package App::ClusterSSH::L10N::en;
use base 'App::ClusterSSH::L10N';

%Lexicon = ( '_AUTO' => 1, );

1;

=pod

=head1 

App::ClusterSSH::L10N::en - Base English translations module

=head1 SYNOPSIS

    use App::ClusterSSH::L10N;
    my $lang = ClusterSSH::L10N->get_handle('en');
    $lang->maketext('text to localise with args [_1]', $arg1);

=head1 DESCRIPTION

L<Locale::Maketext> based translation module for ClusterSSH. See 
L<Locale::Maketext> for more information and usage.

=head1 METHODS

No method are exported.  See L<Locale::Maketext>.

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
