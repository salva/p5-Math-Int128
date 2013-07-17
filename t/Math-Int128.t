#!/usr/bin/perl

use strict;
use warnings;

use Test::More 0.88;

use Math::Int128 qw(int128 int128_to_number
                    net_to_int128 int128_to_net
                    native_to_int128 int128_to_native);

my $i = int128('1234567890123456789');
my $j = $i + 1;
my $k = (int128(1) << 60) + 255;

# 1
ok($i == '1234567890123456789');

ok($j - 1 == '1234567890123456789');

ok (($k & 127) == 127);

ok (($k & 256) == 0);

# 5
ok ($i * 2 == $j + $j - 2);

ok ($i * $i * $i * $i == ($j * $j - 2 * $j + 1) * ($j * $j - 2 * $j + 1));

ok (($i / $j) == 0);

ok ($j / $i == 1);

ok ($i % $j == $i);

# 10
ok ($j % $i == 1);

ok (($j += 1) == $i + 2);

ok ($j == $i + 2);

ok (($j -= 3) == $i - 1);

ok ($j == $i - 1);

$j = $i;
# 15
ok (($j *= 2) == $i << 1);

ok (($j >> 1) == $i);

ok (($j / 2) == $i);

$j = $i + 2;

ok (($j %= $i) == 2);

ok ($j == 2);

# 20
ok (($j <=> $i) < 0);

ok (($i <=> $j) > 0);

ok (($i <=> $i) == 0);

ok (($j <=> 2) == 0);

ok ($j < $i);

# 25
ok ($j <= $i);

ok (!($i < $j));

ok (!($i <= $j));

ok ($i <= $i);

ok ($j >= $j);

# 30
ok ($i > $j);

ok ($i >= $j);

ok (!($j > $i));

ok (!($j >= $i));

ok (int(log(int128(1)<<50)/log(2)+0.001) == 50);

# 35

my $n = int128_to_net(-1);
ok (join(" ", unpack "C*" => $n) eq join(" ", (255) x 16));

ok (net_to_int128($n) == -1);

ok (native_to_int128(int128_to_native(-1)) == -1);

ok (native_to_int128(int128_to_native(0)) == 0);

ok (native_to_int128(int128_to_native(-12343)) == -12343);

# 40

$n = pack(NNNN => 0, 0, 0x01020304, 0x05060708);
ok (net_to_int128($n) == ((int128(0x01020304) << 32) + 0x05060708));

$n = pack(NNNN => 0, 0x01020304, 0, 0x05060708);
ok (net_to_int128($n) == ((int128(0x01020304) << 64) + 0x05060708));

$n = pack(NNNN => 0x01020304, 0, 0, 0x05060708);
ok (net_to_int128($n) == ((int128(0x01020304) << 96) + 0x05060708));

ok ((($i | $j) & 1) != 0);

ok ((($i & $j) & 1) == 0);

# 45

my $l = int128("1271310319617");
is ("$l", "1271310319617", "string to/from int128 conversion");

{
    use integer;
    my $int = int128(255);
    is($int, 255);
    $int <<= 32;
    $int |= 4294967295;
    is($int, '1099511627775');
}

my $two  = int128(2);
my $four = int128(4);
is ($two  ** -1, 0, "signed pow 2**-1");
is ($four ** -1, 0, "signed pow 4**-1");

for my $j (0..127) {
    my $one = int128(1);

    is($two  ** $j, $one <<     $j, "signed pow 2**$j");
    is($four ** $j, $one << 2 * $j, "signed pow 4**$j") if $j < 64;

    is($one << $j, $two ** $j, "$one << $j");

    $one <<= $j;
    is($one, $two ** $j, "$one <<= $j");

    next unless $j;

    my $max = (((int128(2)**126)-1)*2)+1;
    is($max >> $j, $max / ( 2**$j ), "max int128 >> $j");

    my $copy = int128($max);
    $copy >>= $j;
    is($copy, $max / ( 2**$j ), "max int128 >>= $j");

}

for my $i (5..9) {
    for my $j (0..40) { # 9**40 < 2**127
        is(int128($i) ** $j, slow_pow($i, $j), "signed pow $i ** $j");
    }
}

done_testing();

sub slow_pow {
    my ($a, $b) = @_;
    my $acu = int128(1);
    $acu *= $a for 1..$b;
    $acu;
}
