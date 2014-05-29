package App::ClusterSSH::L10N::en;
use base 'App::ClusterSSH::L10N';

%Lexicon = ( '_AUTO' => 1, 
  '_DESCRIPTION' => q{The command opens an administration console and an xterm to all specified hosts.  Any text typed into the administration console is replicated to all windows.  All windows may also be typed into directly.

This tool is intended for (but not limited to) cluster administration where the same configuration or commands must be run on each node within the cluster.  Performing these commands all at once via this tool ensures all nodes are kept in sync.

Connections are opened via ssh, so a correctly installed and configured ssh installation is required.  If, however, the program is called by "crsh" then the rsh protocol is used (and the communications channel is insecure), or by "ctel" then telnet is used, or by "ccon" then console is used.

Extra caution should be taken when editing system files such as /etc/inet/hosts as lines may not necessarily be in the same order.  Assuming line 5 is the same across all servers and modifying that is dangerous.  It's better to search for the specific line to be changed and double-check before changes are committed.},

    '_FURTHER_NOTES' => q{Further Notes},
    '_OPTIONS' => q{Some of these options may also be defined within the configuration file. 

Default options are shown as appropriate.
    },

);

1;

=pod

=head1 NAME

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

Duncan Ferguson, C<< <duncan_j_ferguson at yahoo.co.uk> >>

=head1 LICENSE AND COPYRIGHT

Copyright 1999-2010 Duncan Ferguson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
