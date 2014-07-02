package App::ClusterSSH::Helper;

use strict;
use warnings;

use version;
our $VERSION = version->new('0.02');

use Carp;
use Try::Tiny;

use base qw/ App::ClusterSSH::Base /;

sub new {
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

    return $self;
}

sub script {
    my ( $self, $config ) = @_;

    if(! defined $config || ref $config ne "HASH") {
        croak(
            App::ClusterSSH::Exception::Helper->throw(
                error => 'No configuration provided or in wrong format',
            ),
        );
    }

    foreach my $arg ( "comms", $config->{comms}, $config->{comms} . '_args', 'command', 'auto_close'
    ) {
        if( !defined $config->{ $arg } ) {
            croak(
                App::ClusterSSH::Exception::Helper->throw(
                    error => "Config '$arg' not provided",
                ),
            );
        }
    }

    my $comms          = $config->{ $config->{comms} };
    my $comms_args     = $config->{ $config->{comms} . '_args' };
    my $config_command = $config->{command};
    my $autoclose      = $config->{auto_close};

    my $postcommand
        = $autoclose
        ? "echo Sleeping for $autoclose seconds; sleep $autoclose"
        : "echo Press RETURN to continue; read IGNORE"
        ;    # : "sleep $autoclose";

    my $script = <<"    HERE";
           my \$pipe=shift;
           my \$svr=shift;
           my \$user=shift;
           my \$port=shift;
           my \$mstr=shift;
           my \$command="$comms $comms_args ";
           open(PIPE, ">", \$pipe) or die("Failed to open pipe: \$!\\n");
           print PIPE "\$\$:\$ENV{WINDOWID}" 
               or die("Failed to write to pipe: $!\\n");
           close(PIPE) or die("Failed to close pipe: $!\\n");
           if(\$svr =~ m/==\$/)
           {
               \$svr =~ s/==\$//;
               warn("\\nWARNING: failed to resolve IP address for \$svr.\\n\\n"
               );
               sleep 5;
           }
           if(\$mstr) {
               unless("$comms" ne "console") {
                   \$mstr = \$mstr ? "-M \$mstr " : "";
                   \$command .= \$mstr;
               }
           }
           if(\$user) {
               unless("$comms" eq "telnet") {
                   \$user = \$user ? "-l \$user " : "";
                   \$command .= \$user;
               }
           }
           if("$comms" eq "telnet") {
               \$command .= "\$svr \$port";
           } else {
               if (\$port) {
                   \$command .= "-p \$port \$svr";
               } else {
                 \$command .= "\$svr";
               }
           }
           if("$config_command") {
            \$command .= " \\\"$config_command\\\"";
           }
           \$command .= " ; $postcommand";
           warn("Running:\$command\\n"); # for debug purposes
           exec(\$command);
    HERE

    $self->debug( 4, $script );
    $self->debug( 2, 'Helper script done' );

    return $script;
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

ClusterSSH::Helper - Object representing helper script

=head1 SYNOPSIS

=head1 DESCRIPTION

Object representing application configuration

=head1 METHODS

=over 4

=item $host=ClusterSSH::Helper->new ({ })

Create a new helper object.

=item $host=ClusterSSH::Helper->script ({ })

Return the helper script

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
