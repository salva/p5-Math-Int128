use ExtUtils::MakeMaker;

use Config;

my $mm = WriteMakefile(NAME          => 'Math::Int128',
                       VERSION_FROM  => 'lib/Math/Int128.pm',
                       ABSTRACT_FROM => 'lib/Math/Int128.pm',
                       AUTHOR        => 'Salvador Fandino <sfandino@yahoo.com>',
                       PREREQ_PM     => { 'Math::Int64' => '0.27_04' },
                       LIBS          => [''],
                       DEFINE        => '',
                       INC           => '-I.',
                       # OPTIMIZE    => '-g -O0',
                       OBJECT        => '$(O_FILES)',
                      );

my $cc = (grep defined, $mm->{CC}, $Config{cc}, 'cc')[0];
my $cc_version = `$cc --version --verbose 2>&1`;
unless ($cc_version =~ /^GNU\s+C\s+\([^)]*\)\s+version\s+(4\.(\d+)\S*)/im and $2 >= 4) {
    unlink $mm->{MAKEFILE};
    die "This module requires version 4.4 or above of the GCC compiler.\nAborting!\n\n"
}
print "GNU C compiler version $1 found, good!\n";

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
