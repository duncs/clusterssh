use strict;
use warnings;

package App::ClusterSSH::Range;

# ABSTRACT: Expand ranges such as  {0..1} as well as other bsd_glob specs

=head1 SYNOPSIS

    use App::ClusterSSH::Range;
    my $range=App::ClusterSSH::Range->new();
    my @list = $range->expand('range{0..5}');

=head1 DESCRIPTION

Perform string expansion looking for ranges before then finishing off
using C<File::Glob::bsd_glob>.

=cut

use File::Glob;

=head1 METHODS

=over 4

=item $range = App::ClusterSSH::Range->new();

Create a new object to perform range processing

=cut

sub new {
    my ( $class, %args ) = @_;
    my $self = {%args};
    return bless $self, $class;
}

=item @expanded = $range->expand(@strings);

Expand the given strings.  Ranges are checked for and processed.  The 
resulting string is then put through File::Glob::bsd_glob before being returned.

Ranges are of the form:

 base{start..stop}
 a{0..3} => a0 a1 a2 a3 
 b{4..6,9,12..14} => b4 b5 b6 b9 b12 b13 b14

=back

=cut

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

            $start=$section if(!defined($start));
            $end=$start if(!defined($end));

            foreach my $number ( $start .. $end ) {
                push( @newlist, "$base$number" );
            }
        }
    }

    my @text = map { File::Glob::bsd_glob($_) } @newlist;

    return wantarray ? @text : "@text";
}

1;
