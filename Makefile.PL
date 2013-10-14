use strict;
use warnings;

use lib 'inc';

use Config;
use Config::AutoConf;
use ExtUtils::MakeMaker;

my %deps = ('Math::Int64' => '0.27_04');

unless (-f "c_api.h") {
    $deps{'Module::CAPIMaker'} = '0.01';
}

unless (-f "perl_math_int64.c" and -f "perl_math_int64.h") {
    warn "perl_math_int64.c or perl_math_int64.h files are not found, Math::Int64 has to be cloned under the same root directory as Math::Int128\n";
}

unless ( Config::AutoConf->check_type('unsigned __int128') ) {
    warn <<'EOF';

  It looks like your compiler doesn't support the "unsigned __int128"
  type. This type is necessary to compile the Math::Int128 module.

  This type is supported by GCC 4.4+ and clang 3.2+.

EOF

    exit 1;
}

my $mm = WriteMakefile(NAME          => 'Math::Int128',
                       VERSION_FROM  => 'lib/Math/Int128.pm',
                       ABSTRACT_FROM => 'lib/Math/Int128.pm',
                       AUTHOR        => 'Salvador Fandino <sfandino@yahoo.com>',
                       PREREQ_PM     => \%deps,
                       TEST_REQUIRES => { 'Test::More' => '0.88' },
                       INC           => '-I.',
                       # OPTIMIZE    => '-g -O0',
                       OBJECT        => '$(O_FILES)',
                       META_MERGE    => {
                           resources => {
                               repository  =>  'https://github.com/salva/p5-Math-Int128',
                           },
                      },
                      );


package MY;

sub postamble {
    my $self = shift;
    my $author = $self->{AUTHOR};
    $author = join(', ', @$author) if ref $author;
    $author =~ s/'/'\''/g;

    return <<MAKE_FRAG

c_api.h: c_api.decl
	make_perl_module_c_api module_name=\$(NAME) module_version=\$(VERSION) author='$author'
MAKE_FRAG
}

sub init_dirscan {
    my $self = shift;
    $self->SUPER::init_dirscan(@_);
    push @{$self->{H}}, 'c_api.h' unless grep $_ eq 'c_api.h', @{$self->{H}};
}
