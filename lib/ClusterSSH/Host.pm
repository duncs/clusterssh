# $Id$
package ClusterSSH::Host;

use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;

{
    use base qw/ ClusterSSH::Base /;

    my %hostname_of;
    my %username_of;
    my %port_of;

    sub new {
        my ( $class, $arg_ref ) = @_;

        croak 'hostname is undefined' if ( !$arg_ref->{hostname} );

        # remove any keys undef values - must be a better way...
        foreach my $remove (qw/ port username /) {
            if ( !$arg_ref->{$remove} && grep {/^$remove$/} keys(%$arg_ref) )
            {
                delete( $arg_ref->{$remove} );
            }
        }

        my $self = $class->SUPER::new($arg_ref);

        $hostname_of{ $self->id } = $arg_ref->{hostname};
        if ( defined $arg_ref->{username} ) {
            $username_of{ $self->id } = $arg_ref->{username};
        }

        if ( defined $arg_ref->{port} ) {
            $port_of{ $self->id } = $arg_ref->{port};
        }

        return $self;
    }

    sub get_hostname {
        my ($self) = @_;
        return $hostname_of{ $self->id };
    }

    sub get_username {
        my ($self) = @_;
        return $username_of{ $self->id };
    }

    sub set_username {
        my ( $self, $new_username ) = @_;
        $username_of{ $self->id } = $new_username;
        return $self;
    }

    sub get_port {
        my ($self) = @_;
        return $port_of{ $self->id };
    }

    sub set_port {
        my ( $self, $new_port ) = @_;
        $port_of{ $self->id } = $new_port;
        return $self;
    }

    sub parse_host_string {
        my ( $self, $host_string ) = @_;

        # check for bracketed IPv6 addresses
        if ($host_string =~ m{
            \A 
            (?:(.*?)@)?     # username@ (optional)
            \[([\w:]*)\]    # [<sequence of chars>]
            (?::(\d+))?     # :port     (optional)
            \z
        }xms
            )
        {
            return $self->new(
                {   username => $1,
                    hostname => $2,
                    port     => $3,
                }
            );
        }

        # check for standard IPv4 host.domain/IP address
        if ($host_string =~ m{
            \A 
            (?:(.*?)@)?     # username@ (optional)
            ([\w\.-]*)      # hostname[.domain[.domain] | 123.123.123.123
            (?::(\d+))?     # :port     (optional)
            \z
        }xms
            )
        {
            return __PACKAGE__->new(
                {   username => $1,
                    hostname => $2,
                    port     => $3,
                }
            );
        }

        # Check for unbracketed IPv6 addresses as best we can...
        # first, see if there is a username to grab
        my $username;
        if ( $host_string =~ s/\A(?:(.*)@)// ) {
            $username = $1;
        }

        # reset to undef if necessary
        $username = undef if ( !$username );

        # use number of colons as a possible indicator
        my $colon_count = $host_string =~ tr/://;

        # if there are 7 colons assume its a full IPv6 address
        # also catch localhost address here
        if ( $colon_count == 7 || $host_string eq '::1' ) {
            return __PACKAGE__->new(
                {   username => $username,
                    hostname => $host_string,
                    port     => undef,
                }
            );
        }

        if (   $colon_count > 1
            && $colon_count < 8
            && $host_string =~ m/:(\d+)$/ )
        {
            warn 'Ambiguous host string: "', $host_string, '"',   $/;
            warn 'Assuming you meant "[',    $host_string, ']"?', $/;

            return __PACKAGE__->new(
                {   username => $username,
                    hostname => $host_string,
                    port     => undef,
                }
            );
        }
        else {
            my ( $hostname, $port ) = $host_string =~ m/(.*)(?::(\d+))?$/;
            return __PACKAGE__->new(
                {   username => $username,
                    hostname => $hostname,
                    port     => $port,
                }
            );
        }

        # if we got this far, we didnt parse the host_string properly
        croak( 'Unable to parse hostname from "', $host_string, '"' );
    }

    use overload (
        q{""} => sub {
            my ($self) = @_;
            return $hostname_of{ $self->id };
        },
        fallback => 1,
    );

}

1;

=pod

=head1 

ClusterSSH::Host

=head1 SYNOPSIS

    use ClusterSSH::Host;

    my $host = ClusterSSH::Host->new({
        hostname => 'hostname',
    });
    my $host = ClusterSSH::Host->parse_host_string('username@hostname:1234');

=head1 DESCRIPTION

Object representing a host.  Include details to contact the host such as
hostname/ipaddress, username and port.

=head1 METHODS

=over 4

=item $host=ClusterSSH::Host->new ({ hostname => 'hostname' })

Create a new host object.  'hostname' is a required arg, 'username' and 
'port' are optional.  Raises exception if an error occurs.

=item $host->get_hostname

=item $host->get_username

=item $host->get_port

Return specific details about the host

=item $host->set_username

=item $host->set_port

Set specific details about the host after its been created.

=item parse_host_string

Given a host string, returns a host object.  Parses hosts such as

=over 4

=item host

=item 192.168.0.1

=item user@host

=item user@192.168.0.1

=item host:port

=item [1234:1234:1234::4567]:port

=item 1234:1234:1234::4567

=back

and so on.  Cope with IPv4 and IPv6 addresses - raises a warning if the
IPv6 address is ambiguous (i.e. in the last example, is the 4567 part of
the IPv6 address or a port definition?) and assumes it is part of address.
Use brackets to avoid seeing warning.

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
