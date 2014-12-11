package inc::CreateCAPI;

use strict;
use warnings;

use Moose;

with 'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileInjector';

sub gather_files {
    my $self = shift;

    my @cmd = (
        'make_perl_module_c_api',
        'module_name=' . ( $self->zilla->name =~ s/-/::/gr ),
        'module_version=' . $self->zilla->version,
        q{author="} . ( join ', ', @{ $self->zilla->authors } ) . q{"},
    );

    $self->log( ["Running @cmd"] );

    system(@cmd) and die "Could not run @cmd";

    return;
}

1;
