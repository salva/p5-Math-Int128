package inc::MyMakeMaker;

use strict;
use warnings;

use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

override _build_WriteMakefile_dump => sub {
    my $self = shift;

    my $dump = super();
    $dump .= <<'EOF';
$WriteMakefileArgs{DEFINE} = _backend_define();
EOF

    return $dump;
};

override _build_MakeFile_PL_template => sub {
    my $self     = shift;
    my $template = super();

    $template =~ s/^WriteMakefile/_check_int128_support();\n\nWriteMakefile/m;

    my $extra = do { local $/; <DATA> };
    return $template . $extra;
};

__PACKAGE__->meta()->make_immutable();

1;

__DATA__

use lib 'inc';
use Config::AutoConf;

sub _check_int128_support {
    my $autoconf = Config::AutoConf->new;

    return
        if $autoconf->check_default_headers()
        && ( $autoconf->check_type('int __attribute__ ((__mode__ (TI)))')
        || $autoconf->check_type('__int128') );

    warn <<'EOF';

  It looks like your compiler doesn't support a 128-bit integer type (one of
  "int __attribute__ ((__mode__ (TI)))" or "__int128"). One of these types is
  necessary to compile the Math::Int128 module.

EOF

    exit 1;
}

sub _backend_define {
    my $backend
        = defined $ENV{MATH_INT64_BACKEND} ? $ENV{MATH_INT64_BACKEND}
        : $Config::Config{ivsize} >= 8     ? 'IV'
        : $Config::Config{doublesize} >= 8 ? 'NV'
        :                                    die <<'EOF';
Unable to find a suitable representation for int64 on your system.
Your Perl must have ivsize >= 8 or doublesize >= 8.
EOF

    print "Using $backend backend\n";

    return '-DINT64_BACKEND_' . $backend;
}

package MY;

sub init_dirscan {
    my $self = shift;
    $self->SUPER::init_dirscan(@_);
    push @{ $self->{H} }, 'c_api.h'
        unless grep { $_ eq 'c_api.h' } @{ $self->{H} };
    return;
}