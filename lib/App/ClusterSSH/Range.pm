use strict;
use warnings;

package App::ClusterSSH::Range;

# ABSTRACT: Expand ranges such as  {0..1} as well as other bsd_glob specs

=head1 SYNOPSIS

use App::ClusterSSH::Range;
my $range=App::ClusterSSH::Range->new();
my @list = $range->expand('range{0..5}');

=head1 DESCRIPTION

This module adds in the numbered range specification as found in Bash 
EXPANSIONS (see the bash S<man> page) before putting the same string 
through C<bsd_glob>.

=cut

use File::Glob ':bsd_glob';

sub new {
    my ( $class, %args ) = @_;
    my $self = {%args};
    return bless $self, $class;
}

sub expand {
    my ( $self, @items ) = @_;

    my $range_regexp = qr/^\w+\{[\w\.,]+\}$/;
    my @newlist;
    foreach my $item (@items) {
        if ( $item !~ m/$range_regexp/ ) {
            push( @newlist, $item );
            next;
        }

        my ( $base, $spec ) = $item =~ m/^(.*)?\{(.*)\}$/;

        for my $section ( split( /,/, $spec ) ) {
            my ( $start, $end );

            if ( $section =~ m/\.\./ ) {
                ( $start, $end ) = split( /\.\./, $section, 2 );
            }

            $start //= $section;
            $end   //= $start;

            foreach my $number ( $start .. $end ) {
                push( @newlist, "$base$number" );
            }
        }
    }

    my @text = map { bsd_glob($_) } @newlist;

    return wantarray ? @text : "@text";
}

1;
