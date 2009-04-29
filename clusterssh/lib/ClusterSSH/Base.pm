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

our @EXPORT_OK = qw/ _ident /;

{
    my $debug_level = 0;
    our $language = 'en';
    our $language_handle;

    sub new {
        my ( $class, $arg_ref ) = @_;

        my $self = bless \do { my $anon_scalar; $anon_scalar }, $class;

        if ( $arg_ref->{debug} ) {
            $self->set_debug_level( $arg_ref->{debug} );
        }

        if ( $arg_ref->{lang} ) {
            $self->set_lang( $arg_ref->{lang} );
        }

        $self->debug( 6, 'Arguments to ',
            $class, '->new():', $self->_dump_args_hash($arg_ref) );

        return $self;
    }

    sub _dump_args_hash {
        my ( $class, $arg_ref ) = @_;
        my $string = $/;

        foreach ( sort( keys(%$arg_ref) ) ) {
            $string .= "\t";
            $string .= $_;
            $string .= ' => ';
            $string .= $arg_ref->{$_};
            $string .= $/;
        }
        chomp($string);

        return $string;
    }

    sub id {
        my ($self) = @_;
        return _ident($self);
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

# instead of pulling new module to get one function, alias _ident
# to a core module function
sub _ident {
    my ($id) = @_;
    my $reference = refaddr($id);

    if ( !defined($reference) ) {
        croak( _translate('Reference not passed to _ident') );
    }
    return $reference;
}

1;

=pod

=head1 

ClusterSSH::Base

=head1 SYNOPSIS

    use base qw/ ClusterSSH::Base /;

    # in object new method
    sub new {
        ( $class, $arg_ref ) = @_;
        my $self = $class->SUPER::new($arg_ref);
        return $self;
    }

=head1 DESCRIPTION

Base object to provide some utility functions on objects - should not be 
used directly

=head1 METHODS

These extra methods are provided on the object

=over 4

=item $obj->new({ arg => val, })

Creates object.  In higher debug levels the args are printed out.

=item $obj->id 

Return the unique id of the object for use in subclasses, such as

    $info_for{ $self->id } = $info

=item $obj->debug_level();

Returns current debug level

=item $obj->set_debug_level( n )

Set debug level to 'n' for all child objects.

=item $obj->debug($level, @text)

Output @text on STDOUT if $level is the same or lower that debug_level

=item $obj->set_lang

Set the Locale::Maketext language.  Defaults to 'en'.  Expects the 
ClusterSSH/L10N/{lang}.pm module to exist and contain all relevant 
translations, else defaults to English.

=item $obj->loc('text to translate [_1]')

Using the ClusterSSH/L10N/{lang}.pm module convert the  given text to 
appropriate language.  See L<ClusterSSH::L10N> for more details.  Essentially 
a wrapper to maketext in Locale::Maketext

=item $obj->output(@);

Output text on STDOUT.

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
