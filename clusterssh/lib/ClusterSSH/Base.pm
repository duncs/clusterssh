# $Id$
package ClusterSSH::Base;

use warnings;
use strict;
use Carp;
use Scalar::Util qw(refaddr);
require Exporter;
use ClusterSSH::L10N;

use base qw( Exporter );

# Dont use SVN revision as it can cause problems
use version;
our $VERSION = version->new('0.01');

our @EXPORT_OK = qw/ ident /;

{
    my $debug_level = 0;
    our $language = 'en';
    our $language_handle;

    sub new {
        my ( $class, $args_ref ) = @_;

        my $self = bless \do { my $anon_scalar; $anon_scalar }, $class;

        if ( $args_ref->{debug} ) {
            $self->set_debug_level( $args_ref->{debug} );
        }

        if ( $args_ref->{lang} ) {
            $self->set_lang( $args_ref->{lang} );
        }

        $self->debug( 6, 'Arguments to ',
            $class, '->new():', $self->_dump_args_hash($args_ref) );

        return $self;
    }

    sub _dump_args_hash {
        my ( $class, $args_ref ) = @_;
        my $string = $/;

        $string .= "\t$_ => $args_ref->{$_}" . $/
            foreach ( sort( keys(%$args_ref) ) );
        chomp($string);

        return $string;
    }

    sub id {
        my ($self) = @_;
        return ident($self);
    }

    sub _translate {
        my @args = @_;
        if ( !$language_handle ) {
            $language_handle = ClusterSSH::L10N->get_handle($language);
        }

        return $language_handle->maketext(@args);
    }

    sub loc {
        my ( $self, @args ) = @_;
        return _translate(@args);
    }

    sub set_lang {
        my ( $self, $lang ) = @_;
        $language = $lang;
        if ($self) {
            $self->debug( 6, 'Setting language to ', $lang );
        }
        return $self;
    }

    sub set_debug_level {
        my ( $self, $level ) = @_;
        if ( !defined $level ) {
            croak( _translate('Debug level not provided') );
        }
        if ( $level > 9 ) {
            $level = 9;
        }
        $debug_level = $level;
        return $self;
    }

    sub debug_level {
        my ($self) = @_;
        return $debug_level;
    }

    sub output {
        my ( $self, @text ) = @_;
        print @text, $/;
        return $self;
    }

    sub debug {
        my ( $self, $level, @text ) = @_;
        if ( $level < $debug_level ) {
            $self->output(@text);
        }
        return $self;
    }
}

# instead of pulling new module to get one function, alias ident
# to a core module function
sub ident {
    my ($id) = @_;
    my $reference = refaddr($id);

    if ( !defined($reference) ) {
        croak( _translate('Reference not passed to ident') );
    }
    return $reference;
}

1;

__END__

=head1 NAME

ClusterSSH - [One line description of module's purpose here]


=head1 VERSION

This document describes ClusterSSH version 0.0.1


=head1 SYNOPSIS

    use ClusterSSH;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 SUBROUTINES/METHODS

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
ClusterSSH requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-clusterssh@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Duncan Ferguson  C<< <duncan_j_ferguson@yahoo.co.uk> >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Duncan Ferguson C<< <duncan_j_ferguson@yahoo.co.uk> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
