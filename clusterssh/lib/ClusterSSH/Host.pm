# $Id$
package ClusterSSH::Host;

use strict;
use warnings;

use version;
our $VERSION = version->new(qw$Revision: 1$);

use Carp;

use ClusterSSH::Base qw/ ident /;

{
    my %hostname_of;
    my %username_of;
    my %port_of;

    sub new {
        my ( $class, $arg_ref ) = @_;
        my $new_object = bless \do { my $anon_scalar; $anon_scalar }, $class;

        croak 'hostname is undefined' if ( !$arg_ref->{hostname} );

        $hostname_of{ ident $new_object} = $arg_ref->{hostname};
        if ( defined $arg_ref->{username} ) {
            $username_of{ ident $new_object} = $arg_ref->{username};
        }

        if ( defined $arg_ref->{port} ) {
            $port_of{ ident $new_object} = $arg_ref->{port};
        }

        return $new_object;
    }

    sub get_hostname {
        my ($self) = @_;
        return $hostname_of{ ident $self};
    }

    sub get_username {
        my ($self) = @_;
        return $username_of{ ident $self};
    }

    sub set_username {
        my ( $self, $new_username ) = @_;
        $username_of{ ident $self} = $new_username;
        return $self;
    }

    sub get_port {
        my ($self) = @_;
        return $port_of{ ident $self};
    }

    sub set_port {
        my ( $self, $new_port ) = @_;
        $port_of{ ident $self} = $new_port;
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
            return __PACKAGE__->new(
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
            return $hostname_of{ ident $self};
        },
        fallback => 1,
    );

}

1;
