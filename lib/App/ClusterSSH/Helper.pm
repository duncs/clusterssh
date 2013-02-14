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
    my ($self, $config ) = @_;

    my $comms = $config->{ $config->{comms} };
    my $comms_args = $config->{ $config->{comms} . '_args'};
    my $config_command = $config->{command};
    my $autoclose = $config->{auto_close};

    my $postcommand = $autoclose ? "echo Sleeping for $autoclose seconds; sleep $autoclose" : "echo Press RETURN to continue; read IGNORE"; # : "sleep $autoclose";

#    # P = pipe file
#    # s = server
#    # u = username
#    # p = port
#    # m = ccon master
#    # c = comms command
#    # a = command args
#    # C = command to run
#    my $lelehelper_script = q{
#        use strict; 
#        use warnings;
#        use Getopt::Std;
#        my %opts;
#        getopts('PsupmcaC', \%opts);
#        my $command="$opts{c} $opts{a}";
#        open(PIPE, ">", $opts{P}) or die("Failed to open pipe: $!\n");
#        print PIPE "$$:$ENV{WINDOWID}" 
#            or die("Failed to write to pipe: $!\\n");
#        close(PIPE) or die("Failed to close pipe: $!\\n");
#        if($opts{s} =~ m/==$/)
#        {
#            $opts{s} =~ s/==$//;
#            warn("\nWARNING: failed to resolve IP address for $opts{s}.\n\n");
#            sleep 5;
#        }
#        if($opts{m}) {
#            unless("$comms" ne "console") {
#                $opts{m} = $opts{m} ? "-M $opts{m} " : "";
#                $opts{c} .= $opts{m};
#            }
#        }
#        if($opts{u}) {
#            unless("$comms" eq "telnet") {
#                $opts{u} = $opts{u} ? "-l $opts{u} " : "";
#                $opts{c} .= $opts{u};
#            }
#        }
#        if("$comms" eq "telnet") {
#            $command .= "$opts{s} $opts{p}";
#        } else {
#            if ($opts{p}) {
#              $opts{c} .= "-p $opts{p} $opts{s}";
#            } else {
#              $opts{c} .= "$opts{s}";
#            }
#        }
#        #$command .= " $command || sleep 5";
#        warn("Running:$command\n"); # for debug purposes
#        exec($command);
#    };

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

    $self->debug(4, $script);
    $self->debug(2, 'Helper script done');

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
