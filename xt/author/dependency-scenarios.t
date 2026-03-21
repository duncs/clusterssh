use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Test::More;

use App::ClusterSSH::Base;

# App::ClusterSSH::Base->config checks a package-level configuration first,
# so initialize it once for this test process.
{
    my $bootstrap = App::ClusterSSH::Base->new( debug => 0 );
    eval { $bootstrap->set_config( { bootstrap => 1 } ); 1 };
}

sub _new_base_for_sort {
    return App::ClusterSSH::Base->new(
        debug  => 0,
        parent => { config => { use_natural_sort => 1 }, options => {} },
    );
}

subtest 'Sort::Naturally available scenario' => sub {
    if ( !eval { require Sort::Naturally; 1 } ) {
        plan skip_all => 'Sort::Naturally is not installed in this environment';
    }

    my $base = _new_base_for_sort();
    my $sort = $base->sort();
    my @in   = qw(host2 host10 host1);
    my @out  = $sort->(@in);
    is_deeply( \@out, [ qw(host1 host2 host10) ],
        'natural ordering is used when Sort::Naturally is installed' );
};

subtest 'Sort::Naturally missing scenario' => sub {
    my $base = _new_base_for_sort();
    my $warn = '';
    my $sort;

    {
        local $INC{'Sort/Naturally.pm'};
        delete $INC{'Sort/Naturally.pm'};

        local @INC = (
            sub {
                my ( undef, $filename ) = @_;
                die "blocked for test: $filename\n" if $filename eq 'Sort/Naturally.pm';
                return;
            },
            @INC
        );

        local $SIG{__WARN__} = sub { $warn .= join '', @_ };
        $sort = $base->sort();
    }

    isa_ok( $sort, 'CODE', 'fallback sorter is still returned' );
    my @in  = qw(host2 host10 host1);
    my @out = $sort->(@in);
    is_deeply( \@out, [ qw(host1 host10 host2) ],
        'lexical fallback ordering is used when Sort::Naturally is unavailable' );
    like( $warn, qr/unable to load Sort::Naturally/,
        'warns that Sort::Naturally could not be loaded' );
};

subtest 'XML::Simple available scenario' => sub {
    if ( !eval { require XML::Simple; 1 } ) {
        plan skip_all => 'XML::Simple is not installed in this environment';
    }

    ok( 1, 'XML::Simple can be loaded when installed' );
};

subtest 'XML::Simple missing scenario' => sub {
    my $error = '';

    {
        local $INC{'XML/Simple.pm'};
        delete $INC{'XML/Simple.pm'};

        local @INC = (
            sub {
                my ( undef, $filename ) = @_;
                die "blocked for test: $filename\n" if $filename eq 'XML/Simple.pm';
                return;
            },
            @INC
        );

        eval { require XML::Simple; 1 };
        $error = $@;
    }

    like( $error, qr/blocked for test: XML\/Simple\.pm/,
        'XML::Simple load fails in missing-module scenario' );
};

done_testing();
