#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Benchmark qw(cmpthese);

use Math::GMP;
use Math::Int128 qw(int128);

sub bigrand { join "", map { (0..9)[rand 10] } 0..34 }

my @data = map bigrand(), 0..1000;

my @int128 = map int128, @data;
my @gmp = map Math::GMP->new($_), @data;

cmpthese(-1, { int128 => sub {
                   my $i;
                   $i = ($_ + (1 + $_)) * $_ for @int128
               },
               gmp => sub {
                   my $i;
                   $i = ($_ + (1 + $_)) * $_ for @gmp
               }
             });

