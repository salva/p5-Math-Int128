use ExtUtils::MakeMaker;

use Config;

my $mm = WriteMakefile(NAME         => 'Math::Int128',
                       VERSION_FROM => 'lib/Math/Int128.pm',
                       AUTHOR       => 'Salvador Fandino <sfandino@yahoo.com>',
                       LIBS         => [''],
                       DEFINE       => '',
                       INC          => '-I.',
                       # OPTIMIZE   => '-g -O0',
                       # OBJECT     => '$(O_FILES)',
                      );

my $cc = (grep defined, $mm->{CC}, $onfig{cc}, 'cc')[0];

my $cc_version = `$cc --version`;
unless ($cc_version =~ /cc\s+\([^)]*\)\s+4\.(\d+)/i and $1 >= 6) {
    unlink $mm->{MAKEFILE};
    die "This module requires version 4.6 or above of the GCC compiler.\nAborting!\n\n"
}


