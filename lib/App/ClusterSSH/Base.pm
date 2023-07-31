use warnings;
use strict;

package App::ClusterSSH::Base;

# ABSTRACT: App::ClusterSSH::Base - Base object provding utility functions

=head1 SYNOPSIS

    use base qw/ App::ClusterSSH::Base /;

    # in object new method
    sub new {
        ( $class, $arg_ref ) = @_;
        my $self = $class->SUPER::new($arg_ref);
        return $self;
    }

=head1 DESCRIPTION

Base object to provide some utility functions on objects - should not be 
used directly

=cut

use Carp;
use App::ClusterSSH::L10N;

use Module::Load;

use Exception::Class 1.31 (
    'App::ClusterSSH::Exception',
    'App::ClusterSSH::Exception::Config' => {
        fields => 'unknown_config',
    },
    'App::ClusterSSH::Exception::Cluster',
    'App::ClusterSSH::Exception::LoadFile',
    'App::ClusterSSH::Exception::Helper',
    'App::ClusterSSH::Exception::Getopt',
);

my $debug_level = $ENV{CLUSTERSSH_DEBUG} || 0;
our $language = 'en';
our $language_handle;
our $app_configuration;

sub new {
    my ( $class, %args ) = @_;

    my $config = {
        lang => 'en',
        %args,
    };

    my $self = bless $config, $class;

    $self->set_debug_level( $config->{debug} ) if ( $config->{debug} );
    $self->set_lang( $config->{lang} );

    $self->debug(
        7,
        $self->loc( 'Arguments to [_1]->new(): ', $class ),
        $self->_dump_args_hash(%args),
    );

    return $self;
}

sub _dump_args_hash {
    my ( $class, %args ) = @_;
    my $string = $/;

    foreach ( sort( keys(%args) ) ) {
        $string .= "\t";
        $string .= $_;
        $string .= ' => ';
        if ( ref( $args{$_} ) eq 'ARRAY' ) {
            $string .= "@{ $args{$_} }";
        }
        else {
            $string .= $args{$_};
        }
        $string .= ',';
        $string .= $/;
    }
    chomp($string);

    return $string;
}

sub _translate {
    my @args = @_;
    if ( !$language_handle ) {
        $language_handle = App::ClusterSSH::L10N->get_handle($language);
    }

    return $language_handle->maketext(@args);
}

sub loc {
    my ( $self, @args ) = @_;
    $_ ||= q{} foreach (@args);
    return _translate(@args);
}

sub set_lang {
    my ( $self, $lang ) = @_;
    $self->debug( 6, $self->loc( 'Setting language to "[_1]"', $lang ), );
    return $self;
}

sub set_debug_level {
    my ( $self, $level ) = @_;
    if ( !defined $level ) {
        croak(
            App::ClusterSSH::Exception->throw(
                error => _translate('Debug level not provided')
            )
        );
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

sub stdout_output {
    my ( $self, @text ) = @_;
    print @text, $/;
    return $self;
}

sub debug {
    my ( $self, $level, @text ) = @_;
    if ( $level <= $debug_level ) {
        $self->stdout_output(@text);
    }
    return $self;
}

sub exit {
    my ($self) = @_;

    exit;
}

sub config {
    my ($self) = @_;

    if ( !$app_configuration ) {
        croak(
            App::ClusterSSH::Exception->throw(
                _translate('config has not yet been set')
            )
        );
    }

    return $self->{parent}->{config}
        if $self->{parent}
        && ref $self->{parent} eq "HASH"
        && $self->{parent}->{config};

    return $app_configuration;
}

sub options {
    my ($self) = @_;
    return $self->{parent}->{options}
        if $self->{parent} && $self->{parent}->{options};
    return;
}

sub set_config {
    my ( $self, $config ) = @_;

    if ($app_configuration) {
        croak(
            App::ClusterSSH::Exception->throw(
                _translate('config has already been set')
            )
        );
    }

    if ( !$config ) {
        croak(
            App::ClusterSSH::Exception->throw(
                _translate('passed config is empty')
            )
        );
    }

    $self->debug( 3, _translate('Setting app configuration') );

    $app_configuration = $config;

    return $self;
}

sub load_file {
    my ( $self, %args ) = @_;

    if ( !$args{filename} ) {
        croak(
            App::ClusterSSH::Exception->throw(
                error => '"filename" arg not passed'
            )
        );
    }

    if ( !$args{type} ) {
        croak(
            App::ClusterSSH::Exception->throw(
                error => '"type" arg not passed'
            )
        );
    }

    $self->debug( 2, 'Loading in config file: ', $args{filename} );

    if ( !-e $args{filename} ) {
        croak(
            App::ClusterSSH::Exception::LoadFile->throw(
                error => $self->loc(
                    'Unable to read file [_1]: [_2]' . $/, $args{filename},
                    $!
                ),
            ),
        );
    }

    my $regexp
        = $args{type} eq 'config'  ? qr/\s*(\S+)\s*=\s*(.*)/
        : $args{type} eq 'cluster' ? qr/\s*(\S+)\s+(.*)/
        : croak(
        App::ClusterSSH::Exception::LoadFile->throw(
            error => 'Unknown arg type: ',
            $args{type}
        )
        );

    open( my $fh, '<', $args{filename} )
        or croak(
        App::ClusterSSH::Exception::LoadFile->throw(
            error => $self->loc(
                "Unable to read file [_1]: [_2]",
                $args{filename}, $!
            )
        ),
        );

    my %results;
    my $line;

    while ( defined( $line = <$fh> ) ) {
        next
            if ( $line =~ /^\s*$/ || $line =~ /^#/ )
            ;    # ignore blank lines & commented lines

        $line =~ s/\s*#.*//;    # remove comments from remaining lines
        $line =~ s/\s*$//;      # remove trailing whitespace

        # look for continuation lines
        chomp $line;
        if ( $line =~ s/\\\s*$// ) {
            $line .= <$fh>;
            redo unless eof($fh);
        }

        next unless $line =~ $regexp;
        my ( $key, $value ) = ( $1, $2 );
        if ( defined $key && defined $value ) {
            if ( $results{$key} ) {
                $results{$key} .= ' ' . $value;
            }
            else {
                $results{$key} = $value;
            }
            $self->debug( 3, "$key=$value" );
            $self->debug( 7, "entry now reads: $key=$results{$key}" );
        }
    }

    close($fh)
        or croak(
        App::ClusterSSH::Exception::LoadFile->throw(
            error => "Could not close $args{filename} after reading: $!"
        ),
        );

    return %results;
}

sub parent {
    my ($self) = @_;
    return $self->{parent};
}

sub sort {
    my $self = shift;

    my $sort = sub { sort @_ };

    return $sort unless $self->config()->{'use_natural_sort'};

    # if the user has asked for natural sorting we need to include an extra
    # module
    if ( $self->config()->{'use_natural_sort'} ) {
        eval { Module::Load::load('Sort::Naturally'); };
        if ($@) {
            warn(
                "natural sorting requested but unable to load Sort::Naturally: $@\n"
            );
        }
        else {
            $sort = sub { Sort::Naturally::nsort(@_) };
        }
    }

    return $sort;
}

1;


=head1 METHODS

These extra methods are provided on the object

=over 4

=item $obj = App::ClusterSSH::Base->new({ arg => val, });

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
App::ClusterSSH/L10N/{lang}.pm module to exist and contain all relevant 
translations, else defaults to English.

=item $obj->loc('text to translate [_1]')

Using the App::ClusterSSH/L10N/{lang}.pm module convert the  given text to 
appropriate language.  See L<App::ClusterSSH::L10N> for more details.  Essentially 
a wrapper to maketext in Locale::Maketext

=item $obj->stdout_output(@);

Output text on STDOUT.

=item $obj->parent;

Returned the object that is the parent of this one, if it was set when the 
object was created

=item %obj->options;

Accessor to configured options, if it is set up by this point

=item $obj->exit;

Stub to allow program to exit neatly from wherever in the code

=item $config = $obj->config;

Returns whatever configuration object has been set up.  Croaks if set_config
hasnt been called

=item $obj->set_config($config);

Set the config to the given value - croaks if has already been called

=item $sort = $obj->sort

Code reference used to sort lists; if configured (and installed) use
Sort;:Naturally, else use perl sort

=item %results = $obj->load_file( filename => '/path/to/file', type => '(cluster|config}' )

Load in the specified file and return a hash, parsing the file depending on
wther it is a config file (key = value) or cluster file (key value)

=back
