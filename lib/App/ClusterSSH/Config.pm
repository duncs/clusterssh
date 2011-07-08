package App::ClusterSSH::Config;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.01');

use Carp;

use base qw/ App::ClusterSSH::Base /;

my %default_config = (
    terminal                   => "xterm",
    terminal_args              => "",
    terminal_title_opt         => "-T",
    terminal_colorize          => 1,
    terminal_bg_style          => 'dark',
    terminal_allow_send_events => "-xrm '*.VT100.allowSendEvents:true'",
    terminal_font              => "6x13",
    terminal_size              => "80x24",

    use_hotkeys             => "yes",
    key_quit                => "Control-q",
    key_addhost             => "Control-Shift-plus",
    key_clientname          => "Alt-n",
    key_history             => "Alt-h",
    key_retilehosts         => "Alt-r",
    key_paste               => "Control-v",
    mouse_paste             => "Button-2",
    auto_quit               => "yes",
    window_tiling           => "yes",
    window_tiling_direction => "right",
    console_position        => "",

    screen_reserve_top    => 0,
    screen_reserve_bottom => 60,
    screen_reserve_left   => 0,
    screen_reserve_right  => 0,

    terminal_reserve_top    => 5,
    terminal_reserve_bottom => 0,
    terminal_reserve_left   => 5,
    terminal_reserve_right  => 0,

    terminal_decoration_height => 10,
    terminal_decoration_width  => 8,

    rsh_args    => "",
    telnet_args => "",
    ssh_args    => "",

    extra_cluster_file => "",

    unmap_on_redraw => "no",

    show_history   => 0,
    history_width  => 40,
    history_height => 10,

    command             => q{},
    max_host_menu_items => 30,

    max_addhost_menu_cluster_items => 6,
    menu_send_autotearoff          => 0,
    menu_host_autotearoff          => 0,

    send_menu_xml_file => $ENV{HOME} . '/.csshrc_send_menu',
);

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%default_config);

    return $self->validate_args(%args);
}

sub validate_args {
    my ( $self, %args ) = @_;

    my @unknown_config = ();

    foreach my $config ( sort( keys(%args) ) ) {
        if ( exists $self->{$config} ) {
            $self->{$config} = $args{$config};
        }
        else {
            push( @unknown_config, $config );
        }
    }

    if (@unknown_config) {
        croak(
            App::ClusterSSH::Exception::Config->throw(
                unknown_config => \@unknown_config,
                error          => $self->loc(
                    'Unknown configuration parameters: [_1]',
                    join( ',', @unknown_config )
                )
            )
        );
    }

    return $self;
}

sub parse_config_file {
    my ( $self, $config_file ) = @_;

    $self->debug( 2, 'Loading in config file: ', $config_file );

    return if ( !-e $config_file || !-r $config_file );

    open( CFG, $config_file ) or die("Couldnt open $config_file: $!");
    my $l;
    my %read_config;
    while ( defined( $l = <CFG> ) ) {
        next
            if ( $l =~ /^\s*$/ || $l =~ /^#/ )
            ;    # ignore blank lines & commented lines
        $l =~ s/#.*//;     # remove comments from remaining lines
        $l =~ s/\s*$//;    # remove trailing whitespace

        # look for continuation lines
        chomp $l;
        if ( $l =~ s/\\\s*$// ) {
            $l .= <CFG>;
            redo unless eof(CFG);
        }

        next unless $l =~ m/\s*(\S+)\s*=\s*(.*)\s*/;
        my ( $key, $value ) = ( $1, $2 );
        if ( defined $key && defined $value ) {
            $read_config{$key} = $value;
            logmsg( 3, "$key=$value" );
        }
    }
    close(CFG);

    # tidy up entries, just in case
    $read_config{terminal_font} =~ s/['"]//g;

    $self->validate_args(%read_config);
}

#use overload (
#    q{""} => sub {
#        my ($self) = @_;
#        return $self->{hostname};
#    },
#    fallback => 1,
#);

1;

=pod

=head1 NAME

ClusterSSH::Config

=head1 SYNOPSIS

=head1 DESCRIPTION

Object representing application configuration

=head1 METHODS

=over 4

=item $host=ClusterSSH::Config->new ({ })

Create a new configuration object.

=item $config->parse_config_file('<filename');

Read in configuration from given filename

=item $config->validate_args();

Validate and apply all configuration loaded at this point

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
