#
# $Id$
#

package ClusterSSH::Config;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use Carp;

{
    use base qw/ ClusterSSH::Base /;

    my %default_config = (
        auto_quit                  => 'yes',
        command                    => '',
        console_position           => '',
        extra_cluster_file         => '',
        history_height             => 10,
        history_width              => 40,
        key_addhost                => 'Control-Shift-plus',
        key_clientname             => 'Alt-n',
        key_history                => 'Alt-h',
        key_paste                  => 'Control-v',
        key_quit                   => 'Control-q',
        key_retilehosts            => 'Alt-r',
        max_host_menu_items        => 30,
        mouse_paste                => 'Button-2',
        screen_reserve_bottom      => 60,
        screen_reserve_left        => 0,
        screen_reserve_right       => 0,
        screen_reserve_top         => 0,
        show_history               => 0,
        terminal_allow_send_events => '-xrm "*.VT100.allowSendEvents:true"',
        terminal_args              => '',
        terminal_bg_style          => 'dark',
        terminal_colorize          => 1,
        terminal_decoration_height => 10,
        terminal_decoration_width  => 8,
        terminal_font              => '6x13',
        terminal_reserve_bottom    => 0,
        terminal_reserve_left      => 5,
        terminal_reserve_right     => 0,
        terminal_reserve_top       => 5,
        terminal_size              => '80x24',
        terminal_title_opt         => '-T',
        terminal                   => 'xterm',
        unmap_on_redraw            => 'no',
        use_hotkeys                => 'yes',
        window_tiling_direction    => 'right',
        window_tiling              => 'yes',
    );

    sub new {
        my ( $class, $arg_ref ) = @_;

        my $self = $class->SUPER::new($arg_ref);

        return $self;
    }

    #    sub get_hostname {
    #        my ($self) = @_;
    #        return $hostname_of{ $self->id };
    #    }

    #    sub set_username {
    #        my ( $self, $new_username ) = @_;
    #        $username_of{ $self->id } = $new_username;
    #        return $self;
    #    }

}

1;

=pod

=head1 

ClusterSSH::Config

=head1 SYNOPSIS

    use ClusterSSH::Config;

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $config=ClusterSSH::Config->new ()

=back

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
