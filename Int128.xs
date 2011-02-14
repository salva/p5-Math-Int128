/* -*- Mode: C -*- */

#define PERL_NO_GET_CONTEXT 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

static HV *package_int128_stash;
static HV *package_uint128_stash;

typedef __int128 int128_t;
typedef unsigned __int128 uint128_t;

//typedef long long int128_t;
//typedef unsigned long long uint128_t;

#define I128LEN sizeof(int128_t)

#define SvI128Y(sv) (*((int128_t*)SvPVX(sv)))
#define SVt_I128 SVt_PV

static SV *
new_si128(pTHX) {
    SV *si128 = newSV(I128LEN);
    SvPOK_on(si128);
    SvCUR_set(si128, I128LEN);
    return si128;
}

#define new_su128 new_si128

static int
SvI128OK(pTHX_ SV *sv) {
    if (SvROK(sv)) {
        SV *si128 = SvRV(sv);
        return (si128 && (SvTYPE(si128) >= SVt_I128) && sv_isa(sv, "Math::Int128"));
    }
    return 0;
}

static int
SvU128OK(pTHX_ SV *sv) {
    if (SvROK(sv)) {
        SV *su128 = SvRV(sv);
        return (su128 && (SvTYPE(su128) >= SVt_I128) && sv_isa(sv, "Math::UInt128"));
    }
    return 0;
}

static SV *
newSVi128(pTHX_ int128_t i128) {
    SV *sv;
    SV *si128 = new_si128(aTHX);
    SvI128Y(si128) = i128;
    sv = newRV_noinc(si128);
    sv_bless(sv, package_int128_stash);
    return sv;
}

static SV *
newSVu128(pTHX_ uint128_t u128) {
    SV *sv;
    SV *su128 = new_su128(aTHX);
    SvI128Y(su128) = u128;
    sv = newRV_noinc(su128);
    sv_bless(sv, package_uint128_stash);
    return sv;
}

#define SvI128X(sv) (SvI128Y(SvRV(sv)))
#define SvU128X(sv) (SvI128Y(SvRV(sv)))

static SV *
SvSI128(pTHX_ SV *sv) {
    if (SvRV(sv)) {
        SV *si128 = SvRV(sv);
        if (si128 && SvPOK(si128) && (SvCUR(si128) == I128LEN))
            return si128;
    }
    Perl_croak(aTHX_ "internal error: reference to int128_t expected");
}

static SV *
SvSU128(pTHX_ SV *sv) {
    if (SvRV(sv)) {
        SV *su128 = SvRV(sv);
        if (su128 && SvPOK(su128) && (SvCUR(su128) == I128LEN))
            return su128;
    }
    Perl_croak(aTHX_ "internal error: reference to uint128_t expected");
}

#define SvI128x(sv) SvI128Y(SvSI128(aTHX_ sv))
#define SvU128x(sv) SvI128Y(SvSU128(aTHX_ sv))

static const U32 my_pow10[] = { 1,
                                10,
                                100,
                                1000,
                                10000,
                                100000,
                                1000000,
                                10000000,
                                100000000,
                                1000000000 };

static uint128_t
atoui128(pTHX_ const char *pv, STRLEN len, char *type) {
    uint128_t u128 = 0;
    STRLEN i;

    if (len == 0) {
        if (ckWARN(WARN_NUMERIC))
            Perl_warner(aTHX_ packWARN(WARN_NUMERIC),
                        "Argument isn't numeric in conversion to %s", type);
        return 0;
    }

    while (1) {
        U32 acu32 = 0;
        for (i = 0; i < 9; i++) {
            U32 c = *(pv++);
            if ((c >= '0') && (c <= '9'))
                acu32 = acu32 * 10 + (c - '0');
            else {
                if (ckWARN(WARN_NUMERIC) && (len != i))
                    Perl_warner(aTHX_ packWARN(WARN_NUMERIC),
                                "Argument isn't numeric in conversion to %s", type);
                return u128 * my_pow10[i] + acu32;
            }
        }
        u128 *= 1000000000;
        u128 += acu32;
        len -= 9;
    }
}

#define skip_zeros for(;len > 1 && *pv == '0'; pv++, len--);

static int128_t
atou128(pTHX_ SV *sv) {
    STRLEN len;
    const char *pv = SvPV_const(sv, len);
    if (len && (*pv == '+')) {
        pv++; len--;
    }
    skip_zeros;
    if ((len >= 39) && (strncmp(pv, "340282366920938463463374607431768211456", len) >= 0))
        Perl_croak(aTHX_ "Integer overflow in conversion to uint128_t");
    return atoui128(aTHX_ pv, len, "uint128_t");
}

static int128_t
atoi128(pTHX_ SV *sv) {
    STRLEN len;
    const char *pv = SvPV_const(sv, len);
    if (len) {
        if (*pv == '+') {
            pv++; len--;
        }
        else if (*pv == '-') {
            pv++; len--;
            skip_zeros;
            if (len >= 39) {
                int cmp = strncmp(pv, "170141183460469231731687303715884105728", len);
                if (cmp == 0)
                    return (((int128_t)1) << 127);
                if (cmp > 0)
                    Perl_croak(aTHX_ "Integer overflow in conversion to int128_t");
            }
            return -atoui128(aTHX_ pv, len, "int128_t");
        }
        skip_zeros;
        if ((len >= 39) && (strncmp(pv, "170141183460469231731687303715884105728", len) >= 0))
            Perl_croak(aTHX_ "Integer overflow in conversion to int128_t");
    }
    return atoui128(aTHX_ pv, len, "int128_t");
}

static int128_t
SvI128(pTHX_ SV *sv) {
    if (SvROK(sv)) {
        SV *si128 = SvRV(sv);
        if (SvPOK(si128) && (SvCUR(si128) == I128LEN) &&
            (sv_isa(sv, "Math::Int128") || sv_isa(sv, "Math::UInt128")))
            return SvI128Y(si128);
    }
    else {
        if (SvIOK(sv)) {
            if (SvIOK_UV(sv))
                return SvUV(sv);
            return SvIV(sv);
        }
        if (SvNOK(sv)) {
            return SvNV(sv);
        }
    }
    return atoi128(aTHX_ sv);
}

static uint128_t
SvU128(pTHX_ SV *sv) {
    if (SvROK(sv)) {
        SV *su128 = SvRV(sv);
        if (SvPOK(su128) && (SvCUR(su128) == I128LEN) &&
            (sv_isa(sv, "Math::UInt128") || sv_isa(sv, "Math::Int128")))
            return SvI128Y(su128);
    }
    else {
        if (SvIOK(sv)) {
            if (SvIOK_UV(sv))
                return SvUV(sv);
            return SvIV(sv);
        }
        if (SvNOK(sv)) return SvNV(sv);
    }
    return atou128(aTHX_ sv);
}

static SV *
si128_to_number(pTHX_ SV *sv) {
    int128_t i128 = SvI128(aTHX_ sv);
    if (i128 < 0) {
        IV iv = i128;
        if (iv == i128)
            return newSViv(iv);
    }
    else {
        UV uv = i128;
        if (uv == i128)
            return newSVuv(uv);
    }
    return newSVnv(i128);
}

static SV *
su128_to_number(pTHX_ SV *sv) {
    uint128_t u128 = SvU128(aTHX_ sv);
    UV uv;
    uv = u128;
    if (uv == u128)
        return newSVuv(uv);
    return newSVnv(u128);
}

#define I128STRLEN 44

static STRLEN
u128_to_string(uint128_t u128, char *to) {
    char str[I128STRLEN];
    int i, len = 0;
    while (u128) {
        str[len++] = '0' + u128 % 10;
        u128 /= 10;
    }
    if (len) {
        for (i = len; i--;) *(to++) = str[i];
        return len;
    }
    else {
        to[0] = '0';
        return 1;
    }
}

static STRLEN
i128_to_string(int128_t i128, char *to) {
    if (i128 < 0) {
        *(to++) = '-';
        return u128_to_string(-i128, to) + 1;
    }
    return u128_to_string(i128, to);
}

static void
u128_to_hex(uint128_t i128, char *to) {
    int i = I128LEN * 2;
    while (i--) {
        int v = i128 & 15;
        to[i] = v + ((v > 9) ? ('A' - 10) : '0');
        i128 >>= 4;
    }
}

MODULE = Math::Int128		PACKAGE = Math::Int128			PREFIX=miu128_	

BOOT:
package_int128_stash = gv_stashsv(newSVpv("Math::Int128", 0), 1);
package_uint128_stash = gv_stashsv(newSVpv("Math::UInt128", 0), 1);

SV *
miu128_int128(value=0)
    SV *value;
CODE:
    RETVAL = newSVi128(aTHX_ (value ? SvI128(aTHX_ value) : 0));
OUTPUT:
    RETVAL

SV *
miu128_uint128(value=0)
    SV *value;
CODE:
    RETVAL = newSVu128(aTHX_ (value ? SvU128(aTHX_ value) : 0));
OUTPUT:
    RETVAL

SV *
miu128_int128_to_number(self)
    SV *self
CODE:
    RETVAL = si128_to_number(aTHX_ self);
OUTPUT:
    RETVAL

SV *
miu128_uint128_to_number(self)
    SV *self
CODE:
    RETVAL = su128_to_number(aTHX_ self);
OUTPUT:
    RETVAL

SV *
miu128_net_to_int128(net)
    SV *net;
PREINIT:
    STRLEN len;
    unsigned char *pv = (unsigned char *)SvPV(net, len);
CODE:
    if (len != 16)
        Perl_croak(aTHX_ "Invalid length for int128_t");
    RETVAL = newSVi128(aTHX_
                       (((((((((((((((((((((((((((((((int128_t)pv[0]) << 8)
                                                   + (int128_t)pv[1]) << 8)
                                                 + (int128_t)pv[2]) << 8)
                                               + (int128_t)pv[3]) << 8)
                                             + (int128_t)pv[4]) << 8)
                                           + (int128_t)pv[5]) << 8)
                                         + (int128_t)pv[6]) << 8)
                                       + (int128_t)pv[7]) << 8)
                                     + (int128_t)pv[8]) << 8)
                                   + (int128_t)pv[9]) << 8)
                                 + (int128_t)pv[10]) << 8)
                               + (int128_t)pv[11]) << 8)
                             + (int128_t)pv[12]) << 8)
                           + (int128_t)pv[13]) << 8)
                         + (int128_t)pv[14]) << 8)
                       + (int128_t)pv[15]);
OUTPUT:
    RETVAL

SV *
miu128_net_to_uint128(net)
    SV *net;
PREINIT:
    STRLEN len;
    unsigned char *pv = (unsigned char *)SvPV(net, len);
CODE:
    if (len != 16)
        Perl_croak(aTHX_ "Invalid length for uint128_t");
    RETVAL = newSVu128(aTHX_
                       (((((((((((((((((((((((((((((((uint128_t)pv[0]) << 8)
                                                   + (uint128_t)pv[1]) << 8)
                                                 + (uint128_t)pv[2]) << 8)
                                               + (uint128_t)pv[3]) << 8)
                                             + (uint128_t)pv[4]) << 8)
                                           + (uint128_t)pv[5]) << 8)
                                         + (uint128_t)pv[6]) << 8)
                                       + (uint128_t)pv[7]) << 8)
                                     + (uint128_t)pv[8]) << 8)
                                   + (uint128_t)pv[9]) << 8)
                                 + (uint128_t)pv[10]) << 8)
                               + (uint128_t)pv[11]) << 8)
                             + (uint128_t)pv[12]) << 8)
                           + (uint128_t)pv[13]) << 8)
                         + (uint128_t)pv[14]) << 8)
                       + (uint128_t)pv[15]);
OUTPUT:
    RETVAL

SV *
miu128_int128_to_net(self)
    SV *self
PREINIT:
    char *pv;
    int128_t i128 = SvI128(aTHX_ self);
    int i;
CODE:
    RETVAL = newSV(I128LEN);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, I128LEN);
    pv = SvPVX(RETVAL);
    pv[I128LEN] = '\0';
    for (i = I128LEN; i >= 0; i--, i128 >>= 8)
        pv[i] = i128;
OUTPUT:
    RETVAL

SV *
miu128_uint128_to_net(self)
    SV *self
PREINIT:
    char *pv;
    uint128_t u128 = SvU128(aTHX_ self);
    int i;
CODE:
    RETVAL = newSV(I128LEN);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, I128LEN);
    pv = SvPVX(RETVAL);
    pv[I128LEN] = '\0';
    for (i = I128LEN; i >= 0; i--, u128 >>= 8)
        pv[i] = u128;
OUTPUT:
    RETVAL

SV *
miu128_native_to_int128(native)
    SV *native
PREINIT:
    STRLEN len;
    char *pv = SvPV(native, len);
CODE:
    if (len != I128LEN)
        Perl_croak(aTHX_ "Invalid length for int128_t");
    RETVAL = newSVi128(aTHX_ 0);
    Copy(pv, &(SvI128X(RETVAL)), I128LEN, char);
OUTPUT:
    RETVAL

SV *
miu128_native_to_uint128(native)
    SV *native
PREINIT:
    STRLEN len;
    char *pv = SvPV(native, len);
CODE:
    if (len != I128LEN)
        Perl_croak(aTHX_ "Invalid length for uint128_t");
    RETVAL = newSVu128(aTHX_ 0);
    Copy(pv, &(SvU128X(RETVAL)), I128LEN, char);
OUTPUT:
    RETVAL

SV *
miu128_int128_to_native(self)
    SV *self
PREINIT:
    char *pv;
    int128_t i128 = SvI128(aTHX_ self);
CODE:
    RETVAL = newSV(I128LEN);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, I128LEN);
    pv = SvPVX(RETVAL);
    Copy(&i128, pv, I128LEN, char);
    pv[I128LEN] = '\0';
OUTPUT:
    RETVAL

SV *
miu128_uint128_to_native(self)
    SV *self
PREINIT:
    char *pv;
    uint128_t u128 = SvU128(aTHX_ self);
CODE:
    RETVAL = newSV(I128LEN);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, I128LEN);
    pv = SvPVX(RETVAL);
    Copy(&u128, pv, I128LEN, char);
    pv[I128LEN] = '\0';
OUTPUT:
    RETVAL

SV *
miu128_uint128_to_hex(self)
    SV *self
PREINIT:
    char *pv;
    uint128_t u128 = SvU128(aTHX_ self);
CODE:
    RETVAL = newSV(I128LEN * 2);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, I128LEN * 2);
    pv = SvPVX(RETVAL);
    u128_to_hex(u128, pv);
OUTPUT:
    RETVAL

SV *
miu128_int128_to_hex(self)
    SV *self
PREINIT:
    char *pv;
    uint128_t u128 = SvI128(aTHX_ self);
CODE:
    RETVAL = newSV(I128LEN * 2);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, I128LEN * 2);
    pv = SvPVX(RETVAL);
    u128_to_hex(u128, pv);
OUTPUT:
    RETVAL

MODULE = Math::Int128		PACKAGE = Math::Int128		PREFIX=mi128
PROTOTYPES: DISABLE

SV *
mi128_inc(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    SvI128x(self)++;
    RETVAL = self;
    SvREFCNT_inc(RETVAL);
OUTPUT:
    RETVAL

SV *
mi128_dec(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    SvI128x(self)--;
    RETVAL = self;
    SvREFCNT_inc(RETVAL);
OUTPUT:
    RETVAL

SV *
mi128_add(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    /*
    fprintf(stderr, "self: ");
    sv_dump(self);
    fprintf(stderr, "other: ");
    sv_dump(other);
    fprintf(stderr, "rev: ");
    sv_dump(rev);
    fprintf(stderr, "\n");
    */
    if (SvOK(rev)) 
        RETVAL = newSVi128(aTHX_ SvI128x(self) + SvI128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) += SvI128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mi128_sub(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_
                          SvTRUE(rev)
                          ? SvI128(aTHX_ other) - SvI128x(self)
                          : SvI128x(self) - SvI128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) -= SvI128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mi128_mul(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ SvI128x(self) * SvI128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) *= SvI128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mi128_div(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    int128_t up;
    int128_t down;
CODE:
    if (SvOK(rev)) {
        if (SvTRUE(rev)) {
            up = SvI128(aTHX_ other);
            down = SvI128x(self);
        }
        else {
            up = SvI128x(self);
            down = SvI128(aTHX_ other);
        }
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = newSVi128(aTHX_ up/down);
    }
    else {
        down = SvI128(aTHX_ other);
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) /= down;
    }
OUTPUT:
    RETVAL

SV *
mi128_remainder(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    int128_t up;
    int128_t down;
CODE:
    if (SvOK(rev)) {
        if (SvTRUE(rev)) {
            up = SvI128(aTHX_ other);
            down = SvI128x(self);
        }
        else {
            up = SvI128x(self);
            down = SvI128(aTHX_ other);
        }
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = newSVi128(aTHX_ up % down);
    }
    else {
        down = SvI128(aTHX_ other);
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) %= down;
    }
OUTPUT:
    RETVAL

SV *mi128_left(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev)) {
        int128_t a;
        uint128_t b;
        if (SvTRUE(rev)) {
            a = SvI128(aTHX_ other);
            b = SvU128x(self);
        }
        else {
            b = SvI128(aTHX_ other);
            a = SvU128x(self);
        }
        RETVAL = newSVi128(aTHX_ (b < 128 ? (a << b) : 0));
    }
    else {
        uint128_t b = SvU128(aTHX_ other);
        RETVAL = SvREFCNT_inc(self);
        if (b < 128)
            SvI128x(self) <<= b;
        else
            SvI128x(self) = 0;
    }
OUTPUT:
    RETVAL

SV *mi128_right(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev)) {
        int128_t a;
        uint128_t b;
        if (SvTRUE(rev)) {
            a = SvI128(aTHX_ other);
            b = SvU128x(self);
        }
        else {
            b = SvU128(aTHX_ other);
            a = SvI128x(self);
        }
        RETVAL = newSVi128(aTHX_ (b < 128 ? (a >> b) : (a < 0 ? -1 : 0)));
    }
    else {
        uint128_t b = SvU128(aTHX_ other);
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        if (b < 128)
            SvI128x(self) >>= b;
        else
            SvI128x(self) = (SvI128x(self) < 0 ? -1 : 0);
    }
OUTPUT:
    RETVAL

int
mi128_spaceship(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    int128_t left;
    int128_t right;
CODE:
    if (SvTRUE(rev)) {
        left = SvI128(aTHX_ other);
        right = SvI128x(self);
    }
    else {
        left = SvI128x(self);
        right = SvI128(aTHX_ other);
    }
    RETVAL = (left < right ? -1 : left > right ? 1 : 0);
OUTPUT:
    RETVAL

SV *
mi128_eqn(self, other, rev)
    SV *self
    SV *other
    SV *rev = NO_INIT
CODE:
    RETVAL = ( SvI128x(self) == SvI128(aTHX_ other)
               ? &PL_sv_yes
               : &PL_sv_no );
OUTPUT:
    RETVAL

SV *
mi128_nen(self, other, rev)
    SV *self
    SV *other
    SV *rev = NO_INIT
CODE:
    RETVAL = ( SvI128x(self) != SvI128(aTHX_ other)
               ? &PL_sv_yes
               : &PL_sv_no );
OUTPUT:
    RETVAL

SV *
mi128_gtn(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvI128x(self) < SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvI128x(self) > SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mi128_ltn(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvI128x(self) > SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvI128x(self) < SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mi128_gen(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvI128x(self) <= SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvI128x(self) >= SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mi128_len(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvI128x(self) >= SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvI128x(self) <= SvI128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mi128_and(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ SvI128x(self) & SvI128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) &= SvI128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mi128_or(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ SvI128x(self) | SvI128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) |= SvI128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mi128_xor(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ SvI128x(self) ^ SvI128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) ^= SvI128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mi128_not(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = SvI128x(self) ? &PL_sv_no : &PL_sv_yes;
OUTPUT:
    RETVAL

SV *
mi128_bnot(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = newSVi128(aTHX_ ~SvI128x(self));
OUTPUT:
    RETVAL    

SV *
mi128_neg(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = newSVi128(aTHX_ -SvI128x(self));
OUTPUT:
    RETVAL

SV *
mi128_bool(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = SvI128x(self) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mi128_number(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = si128_to_number(aTHX_ self);
OUTPUT:
    RETVAL

SV *
mi128_clone(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = newSVi128(aTHX_ SvI128x(self));
OUTPUT:
    RETVAL

SV *
mi128_string(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
PREINIT:
    STRLEN len;
CODE:
    RETVAL = newSV(I128STRLEN);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, i128_to_string(SvI128x(self), SvPVX(RETVAL)));
OUTPUT:
    RETVAL


MODULE = Math::Int128		PACKAGE = Math::UInt128		PREFIX=mu128
PROTOTYPES: DISABLE

SV *
mu128_inc(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    SvU128x(self)++;
    RETVAL = self;
    SvREFCNT_inc(RETVAL);
OUTPUT:
    RETVAL

SV *
mu128_dec(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    SvU128x(self)--;
    RETVAL = self;
    SvREFCNT_inc(RETVAL);
OUTPUT:
    RETVAL

SV *
mu128_add(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    /*
    fprintf(stderr, "self: ");
    sv_dump(self);
    fprintf(stderr, "other: ");
    sv_dump(other);
    fprintf(stderr, "rev: ");
    sv_dump(rev);
    fprintf(stderr, "\n");
    */
    if (SvOK(rev)) 
        RETVAL = newSVu128(aTHX_ SvU128x(self) + SvU128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) += SvU128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mu128_sub(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_
                          SvTRUE(rev)
                          ? SvU128(aTHX_ other) - SvU128x(self)
                          : SvU128x(self) - SvU128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) -= SvU128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mu128_mul(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ SvU128x(self) * SvU128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) *= SvU128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mu128_div(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    uint128_t up;
    uint128_t down;
CODE:
    if (SvOK(rev)) {
        if (SvTRUE(rev)) {
            up = SvU128(aTHX_ other);
            down = SvU128x(self);
        }
        else {
            up = SvU128x(self);
            down = SvU128(aTHX_ other);
        }
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = newSVu128(aTHX_ up/down);
    }
    else {
        down = SvU128(aTHX_ other);
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) /= down;
    }
OUTPUT:
    RETVAL

SV *
mu128_remainder(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    uint128_t up;
    uint128_t down;
CODE:
    if (SvOK(rev)) {
        if (SvTRUE(rev)) {
            up = SvU128(aTHX_ other);
            down = SvU128x(self);
        }
        else {
            up = SvU128x(self);
            down = SvU128(aTHX_ other);
        }
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = newSVu128(aTHX_ up % down);
    }
    else {
        down = SvU128(aTHX_ other);
        if (!down)
            Perl_croak(aTHX_ "Illegal division by zero");
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) %= down;
    }
OUTPUT:
    RETVAL

SV *mu128_left(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev)) {
        uint128_t a, b;
        if (SvTRUE(rev)) {
            a = SvU128(aTHX_ other);
            b = SvU128x(self);
        }
        else {
            b = SvU128(aTHX_ other);
            a = SvU128x(self);
        }
        RETVAL = newSVu128(aTHX_ (b < 128 ? (a << b) : 0));
    }
    else {
        int128_t b = SvU128(aTHX_ other);
        RETVAL = SvREFCNT_inc(self);
        if (b < 128)
            SvU128x(self) <<= b;
        else
            SvU128x(self) = 0;
    }
OUTPUT:
    RETVAL

SV *mu128_right(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev)) {
        uint128_t a, b;
        if (SvTRUE(rev)) {
            a = SvU128(aTHX_ other);
            b = SvU128x(self);
        }
        else {
            b = SvU128(aTHX_ other);
            a = SvU128x(self);
        }
        RETVAL = newSVu128(aTHX_ (b < 128 ? (a >> b) : 0));
    }
    else {
        uint128_t b = SvU128(aTHX_ other);
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        if (b < 128)
            SvU128x(self) >>= b;
        else
            SvU128x(self) = 0;
    }
OUTPUT:
    RETVAL

int
mu128_spaceship(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    uint128_t left;
    uint128_t right;
CODE:
    if (SvTRUE(rev)) {
        left = SvU128(aTHX_ other);
        right = SvU128x(self);
    }
    else {
        left = SvU128x(self);
        right = SvU128(aTHX_ other);
    }
    RETVAL = (left < right ? -1 : left > right ? 1 : 0);
OUTPUT:
    RETVAL

SV *
mu128_eqn(self, other, rev)
    SV *self
    SV *other
    SV *rev = NO_INIT
CODE:
    RETVAL = ( SvU128x(self) == SvU128(aTHX_ other)
               ? &PL_sv_yes
               : &PL_sv_no );
OUTPUT:
    RETVAL

SV *
mu128_nen(self, other, rev)
    SV *self
    SV *other
    SV *rev = NO_INIT
CODE:
    RETVAL = ( SvU128x(self) != SvU128(aTHX_ other)
               ? &PL_sv_yes
               : &PL_sv_no );
OUTPUT:
    RETVAL

SV *
mu128_gtn(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvU128x(self) < SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvU128x(self) > SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mu128_ltn(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvU128x(self) > SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvU128x(self) < SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mu128_gen(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvU128x(self) <= SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvU128x(self) >= SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mu128_len(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvTRUE(rev))
        RETVAL = SvU128x(self) >= SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
    else
        RETVAL = SvU128x(self) <= SvU128(aTHX_ other) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mu128_and(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ SvU128x(self) & SvU128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) &= SvU128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mu128_or(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ SvU128x(self) | SvU128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) |= SvU128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mu128_xor(self, other, rev)
    SV *self
    SV *other
    SV *rev
CODE:
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ SvU128x(self) ^ SvU128(aTHX_ other));
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvU128x(self) ^= SvU128(aTHX_ other);
    }
OUTPUT:
    RETVAL

SV *
mu128_not(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = SvU128x(self) ? &PL_sv_no : &PL_sv_yes;
OUTPUT:
    RETVAL

SV *
mu128_bnot(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = newSVu128(aTHX_ ~SvU128x(self));
OUTPUT:
    RETVAL    

SV *
mu128_neg(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = newSVu128(aTHX_ -SvU128x(self));
OUTPUT:
    RETVAL

SV *
mu128_bool(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = SvU128x(self) ? &PL_sv_yes : &PL_sv_no;
OUTPUT:
    RETVAL

SV *
mu128_number(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = su128_to_number(aTHX_ self);
OUTPUT:
    RETVAL

SV *
mu128_clone(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = newSVu128(aTHX_ SvU128x(self));
OUTPUT:
    RETVAL

SV *
mu128_string(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
PREINIT:
    STRLEN len;
CODE:
    RETVAL = newSV(I128STRLEN);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, u128_to_string(SvU128x(self), SvPVX(RETVAL)));
OUTPUT:
    RETVAL


MODULE = Math::Int128		PACKAGE = Math::Int128		PREFIX=mi128_
PROTOTYPES: DISABLE

void
mi128_int128_set(self, a=NULL)
    SV *self
    SV *a
CODE:
    SvI128x(self) = (a ? SvI128(aTHX_ a) : 0);

void
mi128_int128_add(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvI128x(self) = SvI128(aTHX_ a) + SvI128(aTHX_ b);

void
mi128_int128_sub(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvI128x(self) = SvI128(aTHX_ a) - SvI128(aTHX_ b);

void
mi128_int128_mul(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvI128x(self) = SvI128(aTHX_ a) * SvI128(aTHX_ b);

void
mi128_int128_div(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvI128x(self) = SvI128(aTHX_ a) / SvI128(aTHX_ b);

void
mi128_int128_mod(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvI128x(self) = SvI128(aTHX_ a) % SvI128(aTHX_ b);

void
mi128_int128_divmod(self, rem, a, b)
    SV *self
    SV *rem
    SV *a
    SV *b
PREINIT:
    int128_t ai, bi, di, ri;
CODE:
    ai = SvI128(aTHX_ a);
    bi = SvI128(aTHX_ b);
    di = ai / bi;
    ri = ai - bi * di;
    SvI128x(self) = di;
    SvI128x(rem) = ri;

void
mi128_int128_not(self, a)
    SV *self
    SV *a
CODE:
     SvI128x(self) = ~SvI128(aTHX_ a);

void
mi128_int128_neg(self, a)
     SV *self
     SV *a
CODE:
     SvI128x(self) = -SvI128(aTHX_ a);

void
mi128_int128_and(self, a, b)
     SV *self
     SV *a
     SV *b
CODE:
     SvI128x(self) = SvI128(aTHX_ a) & SvI128(aTHX_ b);

void
mi128_int128_or(self, a, b)
     SV *self
     SV *a
     SV *b
CODE:
     SvI128x(self) = SvI128(aTHX_ a) | SvI128(aTHX_ b);

void
mi128_int128_xor(self, a, b)
     SV *self
     SV *a
     SV *b
CODE:
     SvI128x(self) = SvI128(aTHX_ a) ^ SvI128(aTHX_ b);

void
mi128_int128_left(self, a, b)
     SV *self
     SV *a
     UV b
CODE:
     SvI128x(self) = SvI128(aTHX_ a) << b;

void
mi128_int128_right(self, a, b)
     SV *self
     SV *a
     UV b
CODE:
     SvI128x(self) = SvI128(aTHX_ a) >> b;


MODULE = Math::Int128		PACKAGE = Math::Int128		PREFIX=mu128_
PROTOTYPES: DISABLE

void
mu128_uint128_set(self, a=NULL)
    SV *self
    SV *a
CODE:
    SvU128x(self) = (a ? SvU128(aTHX_ a) : 0);

void
mu128_uint128_add(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvU128x(self) = SvU128(aTHX_ a) + SvU128(aTHX_ b);

void
mu128_uint128_sub(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvU128x(self) = SvU128(aTHX_ a) - SvU128(aTHX_ b);

void
mu128_uint128_mul(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvU128x(self) = SvU128(aTHX_ a) * SvU128(aTHX_ b);

void
mu128_uint128_div(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvU128x(self) = SvU128(aTHX_ a) / SvU128(aTHX_ b);

void
mu128_uint128_mod(self, a, b)
    SV *self
    SV *a
    SV *b
CODE:
    SvU128x(self) = SvU128(aTHX_ a) % SvU128(aTHX_ b);

void
mu128_uint128_divmod(self, rem, a, b)
    SV *self
    SV *rem
    SV *a
    SV *b
PREINIT:
    uint128_t ai, bi, di, ri;
CODE:
    ai = SvU128(aTHX_ a);
    bi = SvU128(aTHX_ b);
    di = ai / bi;
    ri = ai - bi * di;
    SvU128x(self) = di;
    SvU128x(rem) = ri;

void
mu128_uint128_not(self, a)
    SV *self
    SV *a
CODE:
     SvU128x(self) = ~SvU128(aTHX_ a);

void
mu128_uint128_neg(self, a)
     SV *self
     SV *a
CODE:
     SvU128x(self) = -SvU128(aTHX_ a);

void
mu128_uint128_and(self, a, b)
     SV *self
     SV *a
     SV *b
CODE:
     SvU128x(self) = SvU128(aTHX_ a) & SvU128(aTHX_ b);

void
mu128_uint128_or(self, a, b)
     SV *self
     SV *a
     SV *b
CODE:
     SvU128x(self) = SvU128(aTHX_ a) | SvU128(aTHX_ b);

void
mu128_uint128_xor(self, a, b)
     SV *self
     SV *a
     SV *b
CODE:
     SvU128x(self) = SvU128(aTHX_ a) ^ SvU128(aTHX_ b);

void
mu128_uint128_left(self, a, b)
     SV *self
     SV *a
     UV b
CODE:
     SvU128x(self) = SvU128(aTHX_ a) << b;

void
mu128_uint128_right(self, a, b)
     SV *self
     SV *a
     UV b
CODE:
     SvU128x(self) = SvU128(aTHX_ a) >> b;
