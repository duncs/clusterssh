package App::ClusterSSH::L10N::en;

# ABSTRACT: App::ClusterSSH::L10N::en - Base English translations module

=head1 SYNOPSIS

    use App::ClusterSSH::L10N;
    my $lang = ClusterSSH::L10N->get_handle('en');
    $lang->maketext('text to localise with args [_1]', $arg1);

=head1 DESCRIPTION

L<Locale::Maketext> based translation module for ClusterSSH. See 
L<Locale::Maketext> for more information and usage.

=cut 

use base 'App::ClusterSSH::L10N';

%Lexicon = ( '_AUTO' => 1, );

1;

=head1 METHODS

No method are exported.  See L<Locale::Maketext>.
