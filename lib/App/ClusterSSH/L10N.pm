use strict;
use warnings;

package App::ClusterSSH::L10N;

# ABSTRACT: ClusterSSH::L10N - Base translations module

=head1 SYNOPSIS

    use ClusterSSH::L10N;
    my $lang = ClusterSSH::L10N->get_handle('en');
    $lang->maketext('text to localise with args [_1]', $arg1);

=head1 DESCRIPTION

L<Locale::Maketext> based translation module for ClusterSSH. See 
L<Locale::Maketext> for more information and usage.

NOTE: the default language of this module is English.

=head1 METHODS

See Locale::Maketext - there are currently no extra methods in this module.

=cut

use Locale::Maketext 1.01;
use base qw(Locale::Maketext);

# This projects primary language is English

our %Lexicon = ( '_AUTO' => 1, );

1;
