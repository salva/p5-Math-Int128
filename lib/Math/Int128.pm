package Math::Int128;

use strict;
use warnings;

BEGIN {
    our $VERSION = '0.01';

    require XSLoader;
    XSLoader::load('Math::Int128', $VERSION);
}



require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(int128
                    int128_to_number
                    int128_to_hex
                    net_to_int128 int128_to_net
                    native_to_int128 int128_to_native
                    uint128
                    uint128_to_number
                    uint128_to_hex
                    net_to_uint128 uint128_to_net
                    native_to_uint128 uint128_to_native);

*int128_to_hex = \&uint128_to_hex;

use overload ( '+' => \&_add,
               '+=' => \&_add,
               '-' => \&_sub,
               '-=' => \&_sub,
               '*' => \&_mul,
               '*=' => \&_mul,
               '/' => \&_div,
               '/=' => \&_div,
               '%' => \&_remainder,
               '%=' => \&_remainder,
               'neg' => \&_neg,
               '++' => \&_inc,
               '--' => \&_dec,
               '!' => \&_not,
               '~' => \&_bnot,
               '&' => \&_and,
               '|' => \&_or,
               '^' => \&_xor,
               '<<' => \&_left,
               '>>' => \&_right,
               '<=>' => \&_spaceship,
               '>' => \&_gtn,
               '<' => \&_ltn,
               '>=' => \&_gen,
               '<=' => \&_len,
               '==' => \&_eqn,
               '!=' => \&_nen,
               'bool' => \&_bool,
               '0+' => \&_number,
               '""' => \&_string,
               '=' => \&_clone,
               fallback => 1 );

package Math::UInt128;
use overload ( '+' => \&_add,
               '+=' => \&_add,
               '-' => \&_sub,
               '-=' => \&_sub,
               '*' => \&_mul,
               '*=' => \&_mul,
               '/' => \&_div,
               '/=' => \&_div,
               '%' => \&_remainder,
               '%=' => \&_remainder,
               'neg' => \&_neg,
               '++' => \&_inc,
               '--' => \&_dec,
               '!' => \&_not,
               '~' => \&_bnot,
               '&' => \&_and,
               '|' => \&_or,
               '^' => \&_xor,
               '<<' => \&_left,
               '>>' => \&_right,
               '<=>' => \&_spaceship,
               '>' => \&_gtn,
               '<' => \&_ltn,
               '>=' => \&_gen,
               '<=' => \&_len,
               '==' => \&_eqn,
               '!=' => \&_nen,
               'bool' => \&_bool,
               '0+' => \&_number,
               '""' => \&_string,
               '=' => \&_clone,
               fallback => 1 );


1;

__END__

=head1 NAME

Math::Int128 - Manipulate 128 bits integers in Perl

=head1 SYNOPSIS

  use Math::Int128 qw(int128);

  my $i = int128(1);
  my $j = $i << 100;
  my $k = int128("1234567890123456789000000");
  print($i + $j * 1000000);

=head1 DESCRIPTION

This module adds support for 128 bit integers, signed and unsigned, to
Perl.

=head1 INSTALL

In order to compile this module, the development version of GCC (which
will eventually become GCC 4.6) that includes support for 128 bits
arithmetic is required.

It can be installed as follows:

  $ svn checkout svn://gcc.gnu.org/svn/gcc/trunk gcc
  $ cd gcc
  $ ./configure --disable-bootstrap --prefix=/usr/local/gcc
  $ make
  $ sudo make install

Then, to compile Math::Int128

  $ cd ~/Math-Int128-*
  $ perl Makefile CC=/usr/local/gcc/bin/gcc
  $ make
  $ sudo make install

=head1 API

See L<Math::Int64>. This module provides a similar set of functions,
just S<s/64/128/>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007, 2009, 2011 by Salvador Fandino (sfandino@yahoo.com)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
