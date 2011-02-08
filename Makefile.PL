use ExtUtils::MakeMaker;

WriteMakefile(NAME => 'Math::Int128',
              VERSION_FROM => 'lib/Math/Int128.pm',
              AUTHOR => 'Salvador Fandino <sfandino@yahoo.com>',
              LIBS => [''],
              DEFINE => '',
              INC => '-I.',
              # OPTIMIZE => '-g -O0',
              # Un-comment this if you add C files to link with later:
              # OBJECT => '$(O_FILES)', # link all the C files too
             );
