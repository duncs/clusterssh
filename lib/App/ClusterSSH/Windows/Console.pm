package App::ClusterSSH::Windows::Console;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;
use Gtk2 -init;

use base qw/ App::ClusterSSH::Base /;

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

    #    if ( !$args{hostname} ) {
    #        croak(
    #            App::ClusterSSH::Exception->throw(
    #                error => $class->loc('hostname is undefined')
    #            )
    #        );
    #    }

    #    # remove any keys undef values - must be a better way...
    #    foreach my $remove (qw/ port username /) {
    #        if ( !$args{$remove} && grep {/^$remove$/} keys(%args) ) {
    #            delete( $args{$remove} );
    #        }
    #    }

    $self->{console} = Gtk2::Window->new('toplevel');
    $self->{console}->set_title('ClusterSSH');
    $self->{console}->set_wmclass( 'cssh', 'cssh' );
    $self->{console}->set_resizable(0);
    $self->{console}->signal_connect( destroy => sub { Gtk2->main_quit; } );

    my $vbox = Gtk2::VBox->new( 0, 5 );
    $vbox->set_size_request( 300, 100 );

    my $menubar = Gtk2::MenuBar->new;
    $menubar->append( $self->_file_menu );
    $menubar->append( $self->_host_menu );
    $menubar->append( $self->_send_menu );
    $menubar->append( $self->_help_menu );

    $vbox->pack_start( $menubar, 0, 0, 0 );

    $vbox->show_all;

    $self->{console}->add($vbox);

    return $self;
}

sub _file_menu {
    my ($self) = @_;

    my $items = Gtk2::Menu->new();

    my $item_show_history = Gtk2::MenuItem->new('_Show History');
    $item_show_history->signal_connect(
        'activate' => sub { warn "NOT SET UP YET" } );
    $items->append($item_show_history);

    my $item_exit = Gtk2::MenuItem->new('_Exit');
    $item_exit->signal_connect( 'activate' => sub { Gtk2->main_quit; } );

    $items->append($item_exit);

    my $menu = Gtk2::MenuItem->new('_File');
    $menu->set_submenu($items);

    return $menu;
}

sub _host_menu {
    my ($self) = @_;

    my $items = Gtk2::Menu->new();
    $items->append( Gtk2::TearoffMenuItem->new );

    my $item_retile = Gtk2::MenuItem->new('_Retile Windows');
    $item_retile->signal_connect( 'activate' => sub { warn "NOT SET UP YET" }
    );
    $items->append($item_retile);

    my $item_toggle = Gtk2::MenuItem->new('_Toggle Active Windows');
    $item_toggle->signal_connect( 'activate' => sub { warn "NOT SET UP YET" }
    );
    $items->append($item_toggle);

    my $item_close_inactive = Gtk2::MenuItem->new('_Close Inactive Windows');
    $item_close_inactive->signal_connect(
        'activate' => sub { warn "NOT SET UP YET" } );
    $items->append($item_close_inactive);

    my $item_add = Gtk2::MenuItem->new('_Add Host or Cluster');
    $item_add->signal_connect( 'activate' => sub { warn "NOT SET UP YET" } );
    $items->append($item_add);

    $items->append( Gtk2::SeparatorMenuItem->new() );

    my $menu = Gtk2::MenuItem->new('_Host');
    $menu->set_submenu($items);

    return $menu;
}

sub _send_menu {
    my ($self) = @_;

    my $items = Gtk2::Menu->new();
    $items->append( Gtk2::TearoffMenuItem->new );

    my $menu = Gtk2::MenuItem->new('_Send');
    $menu->set_submenu($items);

    return $menu;
}

sub _help_menu {
    my ($self) = @_;

    my $items = Gtk2::Menu->new();

    my $item_about = Gtk2::MenuItem->new('_About');
    $item_about->signal_connect( 'activate' => sub { warn "NOT SET UP YET" }
    );
    $items->append($item_about);

    my $item_docs = Gtk2::MenuItem->new('_Documentation');
    $item_docs->signal_connect( 'activate' => sub { warn "NOT SET UP YET" } );
    $items->append($item_docs);

    my $menu = Gtk2::MenuItem->new('_Help');
    $menu->set_right_justified(1);
    $menu->set_submenu($items);

    return $menu;
}

sub show {
    my ($self) = @_;
    return $self->{console}->show;
}

sub withdraw {
    my ($self) = @_;
    return $self->{console}->withdraw;
}

1;

=pod

=head1 NAME

ClusterSSH::Console - Object representing a terminal window.

=head1 SYNOPSIS

    use ClusterSSH::Console;

=head1 DESCRIPTION

Object representing a terminal window. 

=head1 METHODS

=over 4

=item $window=ClusterSSH::Console->new ({ something => 'something' })

=back

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
