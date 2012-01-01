/* -*- Mode: C -*- */

#define PERL_NO_GET_CONTEXT 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "perl_math_int64.h"

#if __GNUC__ == 4 && __GNUC_MINOR__ >= 4 && __GNUC_MINOR__ < 6

/* workaroung for gcc 4.4/4.5 - see http://gcc.gnu.org/gcc-4.4/changes.html */
typedef int int128_t __attribute__ ((__mode__ (TI)));
typedef unsigned int uint128_t __attribute__ ((__mode__ (TI)));

#else

typedef __int128 int128_t;
typedef unsigned __int128 uint128_t;

#endif

#define I128LEN sizeof(int128_t)

#define INT128_MAX ((int128_t)((~(uint128_t)0)>>1))
#define INT128_MIN (~INT128_MAX)
#define UINT128_MAX (~(int128_t)0)

int may_die_on_overflow;

#if (PERL_VERSION >= 10)

#ifndef cop_hints_fetch_pvs
#define cop_hints_fetch_pvs(cop, key, flags) \
    Perl_refcounted_he_fetch(aTHX_ (cop)->cop_hints_hash, NULL, STR_WITH_LEN(key), (flags), 0)
#endif

static int
check_die_on_overflow_hint(pTHX) {
    SV *hint = cop_hints_fetch_pvs(PL_curcop, "Math::Int128::die_on_overflow", 0);
    return (hint && SvTRUE(hint));
}

#else

static int
check_die_on_overflow_hint(pTHX) {
    return 1;
}

#endif

static void
overflow(pTHX_ char *msg) {
    if (check_die_on_overflow_hint(aTHX))
        Perl_croak(aTHX_ "Math::Int128 overflow: %s", msg);
}

static char *out_of_bounds_error_s = "number is out of bounds for int128_t conversion";
static char *out_of_bounds_error_u = "number is out of bounds for uint128_t conversion";
static char *mul_error            = "multiplication overflows";
static char *add_error            = "addition overflows";
static char *sub_error            = "subtraction overflows";
static char *inc_error            = "increment operation wraps";
static char *dec_error            = "decrement operation wraps";
static char *left_b_error         = "left-shift right operand is out of bounds";
static char *left_error           = "left shift overflows";
static char *right_b_error        = "right-shift right operand is out of bounds";
static char *right_error          = "right shift overflows";


#include <strtoint128.h>

static HV *package_int128_stash;
static HV *package_uint128_stash;

#define SvI128Y(sv) (*((int128_t*)SvPVX(sv)))
#define SvU128Y(sv) (*((uint128_t*)SvPVX(sv)))
#define SVt_I128 SVt_PV

static SV *
new_si128(pTHX) {
    SV *si128 = newSV(I128LEN);
    SvPOK_on(si128);
    SvCUR_set(si128, I128LEN);
    return si128;
}

#define new_su128 new_si128

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
        if (SvPOK(si128) && (SvCUR(si128) == I128LEN))
            return si128;
    }
    Perl_croak(aTHX_ "internal error: reference to int128_t expected");
}

static SV *
SvSU128(pTHX_ SV *sv) {
    if (SvRV(sv)) {
        SV *su128 = SvRV(sv);
        if (SvPOK(su128) && (SvCUR(su128) == I128LEN))
            return su128;
    }
    Perl_croak(aTHX_ "internal error: reference to uint128_t expected");
}

#define SvI128x(sv) SvI128Y(SvSI128(aTHX_ sv))
#define SvU128x(sv) SvI128Y(SvSU128(aTHX_ sv))

/* static const U32 my_pow10[] = { 1, */
/*                                 10, */
/*                                 100, */
/*                                 1000, */
/*                                 10000, */
/*                                 100000, */
/*                                 1000000, */
/*                                 10000000, */
/*                                 100000000, */
/*                                 1000000000 }; */

/* static uint128_t */
/* atoui128(pTHX_ const char *pv, STRLEN len, char *type) { */
/*     uint128_t u128 = 0; */
/*     STRLEN i; */

/*     if (len == 0) { */
/*         if (ckWARN(WARN_NUMERIC)) */
/*             Perl_warner(aTHX_ packWARN(WARN_NUMERIC), */
/*                         "Argument isn't numeric in conversion to %s", type); */
/*         return 0; */
/*     } */

/*     while (1) { */
/*         U32 acu32 = 0; */
/*         for (i = 0; i < 9; i++) { */
/*             U32 c = *(pv++); */
/*             if ((c >= '0') && (c <= '9')) */
/*                 acu32 = acu32 * 10 + (c - '0'); */
/*             else { */
/*                 if (ckWARN(WARN_NUMERIC) && (len != i)) */
/*                     Perl_warner(aTHX_ packWARN(WARN_NUMERIC), */
/*                                 "Argument isn't numeric in conversion to %s", type); */
/*                 return u128 * my_pow10[i] + acu32; */
/*             } */
/*         } */
/*         u128 *= 1000000000; */
/*         u128 += acu32; */
/*         len -= 9; */
/*     } */
/* } */

/* #define skip_zeros for(;len > 1 && *pv == '0'; pv++, len--); */

/* static int128_t */
/* atou128(pTHX_ SV *sv) { */
/*     STRLEN len; */
/*     const char *pv = SvPV_const(sv, len); */
/*     if (len && (*pv == '+')) { */
/*         pv++; len--; */
/*     } */
/*     skip_zeros; */
/*     if ( (len > 39) || */
/*          ((len == 39) && (strncmp(pv, "340282366920938463463374607431768211456", len) >= 0)) ) */
/*         Perl_croak(aTHX_ "Integer overflow in conversion to uint128_t"); */
/*     return atoui128(aTHX_ pv, len, "uint128_t"); */
/* } */

/* static int128_t */
/* atoi128(pTHX_ SV *sv) { */
/*     STRLEN len; */
/*     const char *pv = SvPV_const(sv, len); */
/*     if (len) { */
/*         if (*pv == '+') { */
/*             pv++; len--; */
/*         } */
/*         else if (*pv == '-') { */
/*             int cmp; */
/*             pv++; len--; */
/*             skip_zeros; */
/*             if (len >= 39) { */
/*                 cmp = strcmp(pv, "170141183460469231731687303715884105728"); */
/*                 if ((len > 39) || (cmp > 0)) */
/*                     Perl_croak(aTHX_ "Integer overflow in conversion to int128_t"); */
/*                 if (cmp == 0) */
/*                     return (((int128_t)1) << 127); */
/*             } */
/*             return -atoui128(aTHX_ pv, len, "int128_t"); */
/*         } */
/*         skip_zeros; */
/*         if ((len >= 39) && (strncmp(pv, "170141183460469231731687303715884105728", len) >= 0)) */
/*             Perl_croak(aTHX_ "Integer overflow in conversion to int128_t"); */
/*     } */
/*     return atoui128(aTHX_ pv, len, "int128_t"); */
/* } */

static int128_t
SvI128(pTHX_ SV *sv) {
    if (SvROK(sv)) {
        SV *si128 = SvRV(sv);
        if (si128 && SvOBJECT(si128)) {
            GV *method;
            HV *stash = SvSTASH(si128);
            char const * classname = HvNAME_get(stash);
            if (strncmp(classname, "Math::", 6) == 0) {
                int u;
                if (classname[6] == 'U') {
                    classname += 7;
                    u = 1;
                }
                else {
                    classname += 6;
                    u = 0;
                }
                if (strncmp(classname, "Int", 3) == 0) {
                    classname += 3;
                    if (strcmp(classname, "128") == 0) {
                        if (!SvPOK(si128) || (SvCUR(si128) != I128LEN))
                            Perl_croak(aTHX_ "Wrong internal representation for %s object", HvNAME_get(stash));
                        if (u) {
                            int128_t u128 = SvU128Y(si128);
                            if (may_die_on_overflow && (u128 > INT128_MAX))
                                overflow(aTHX_ out_of_bounds_error_s);
                            return u128;
                        }
                        return SvI128Y(si128);
                    }
                    if (strcmp(classname, "64") == 0) {
                        if (u) {
                            return SvU64(sv);
                        }
                        return SvI64(sv);
                    }
                }
            }
            method = gv_fetchmethod(stash, "as_int128");
            if (method) {
                SV *result;
                int count;
                dSP;
                ENTER;
                SAVETMPS;
                PUSHSTACKi(PERLSI_MAGIC);
                PUSHMARK(SP);
                XPUSHs(sv);
                PUTBACK;
                count = perl_call_sv( (SV*)method, G_SCALAR );
                SPAGAIN;
                if (count != 1)
                    Perl_croak(aTHX_ "internal error: method call returned %d values, 1 expected", count);
                result = newSVsv(POPs);
                PUTBACK;
                POPSTACK;
                SPAGAIN;
                FREETMPS;
                LEAVE;
                return SvI128(aTHX_ sv_2mortal(result));
            }
        }
    }
    else {
        SvGETMAGIC(sv);
        if (SvIOK(sv)) {
            if (SvIOK_UV(sv))
                return SvUV(sv);
            return SvIV(sv);
        }
        if (SvNOK(sv)) {
            NV nv = SvNV(sv);
            if (may_die_on_overflow &&
                ((nv >= 0x1p127) || (nv < -0x1p127))) overflow(aTHX_ out_of_bounds_error_s);
            return nv;
        }
    }
    return strtoint128(aTHX_ SvPV_nolen(sv), 10, 1);
}

static uint128_t
SvU128(pTHX_ SV *sv) {
    if (SvROK(sv)) {
        SV *su128 = SvRV(sv);
        if (su128 && SvOBJECT(su128)) {
            GV *method;
            HV *stash = SvSTASH(su128);
            char const * classname = HvNAME_get(stash);
            if (strncmp(classname, "Math::", 6) == 0) {
                int u;
                if (classname[6] == 'U') {
                    classname += 7;
                    u = 1;
                }
                else {
                    classname += 6;
                    u = 0;
                }
                if (strncmp(classname, "Int", 3) == 0) {
                    classname += 3;
                    if (strcmp(classname, "128") == 0) {
                        if (!SvPOK(su128) || (SvCUR(su128) != I128LEN))
                            Perl_croak(aTHX_ "Wrong internal representation for %s object", HvNAME_get(stash));
                        if (u)
                            return SvU128Y(su128);
                        else {
                            int128_t i128 = SvI128Y(su128);
                            if (may_die_on_overflow && (i128 < 0)) overflow(aTHX_ out_of_bounds_error_u);
                            return i128;
                        }
                    }
                    if (strcmp(classname, "64") == 0) {
                        if (u) {
                            return SvU64(sv);
                        }
                        else {
                            int64_t i64 = SvI64(sv);
                            if (may_die_on_overflow && (i64 < 0)) overflow(aTHX_ out_of_bounds_error_u);
                            return i64;
                        }
                    }
                }
            }
            method = gv_fetchmethod(stash, "as_uint128");
            if (method) {
                SV *result;
                int count;
                dSP;
                ENTER;
                SAVETMPS;
                PUSHSTACKi(PERLSI_MAGIC);
                PUSHMARK(SP);
                XPUSHs(sv);
                PUTBACK;
                count = perl_call_sv( (SV*)method, G_SCALAR );
                SPAGAIN;
                if (count != 1)
                    Perl_croak(aTHX_ "internal error: method call returned %d values, 1 expected", count);
                result = newSVsv(POPs);
                PUTBACK;
                POPSTACK;
                SPAGAIN;
                FREETMPS;
                LEAVE;
                return SvU128(aTHX_ sv_2mortal(result));
            }

        }
    }
    else {
        SvGETMAGIC(sv);
        if (SvIOK(sv)) {
            if (SvIOK_UV(sv))
                return SvUV(sv);
            else {
                IV iv = SvIV(sv);
                if (may_die_on_overflow && (iv < 0)) overflow(aTHX_ out_of_bounds_error_u);
                return iv;
            }
        }
        if (SvNOK(sv)) {
            NV nv = SvNV(sv);
            if (may_die_on_overflow && ((nv < 0) || (nv >= 0x1p128))) overflow(aTHX_ out_of_bounds_error_u);
            return nv;
        }
    }
    return strtoint128(aTHX_ SvPV_nolen(sv), 10, 0);
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
    may_die_on_overflow = 0;
    package_int128_stash = gv_stashsv(newSVpv("Math::Int128", 0), 1);
    package_uint128_stash = gv_stashsv(newSVpv("Math::UInt128", 0), 1);
    MATH_INT64_BOOT;

void
miu128__set_may_die_on_overflow(v)
    int v
CODE:
    may_die_on_overflow = v;

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

SV *
miu128_string_to_int128(str, base = 0)
    const char *str;
    int base;
CODE:
    RETVAL = newSVi128(aTHX_ strtoint128(aTHX_ str, base, 1));
OUTPUT:
    RETVAL

SV *
miu128_string_to_uint128(str, base = 0)
    const char *str;
    int base;
CODE:
    RETVAL = newSVu128(aTHX_ strtoint128(aTHX_ str, base, 0));
OUTPUT:
    RETVAL

MODULE = Math::Int128		PACKAGE = Math::Int128		PREFIX=mi128
PROTOTYPES: DISABLE

SV *
mi128_inc(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
PREINIT:
    int128_t i128 = SvI128x(self);
CODE:
    if (may_die_on_overflow && (i128 == INT128_MAX)) overflow(aTHX_ inc_error);
    SvI128x(self) = i128 + 1;
    RETVAL = self;
    SvREFCNT_inc(RETVAL);
OUTPUT:
    RETVAL

SV *
mi128_dec(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
PREINIT:
    int128_t i128 = SvI128x(self);
CODE:
    if (may_die_on_overflow && (i128 == 0)) overflow(aTHX_ dec_error);
    SvI128x(self) = i128 - 1;
    RETVAL = self;
    SvREFCNT_inc(RETVAL);
OUTPUT:
    RETVAL

SV *
mi128_add(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    int128_t a = SvI128x(self);
    int128_t b = SvI128(aTHX_ other);
CODE:
    if ( may_die_on_overflow &&
         ( a > 0
           ? ( (b > 0) && (INT128_MAX - a < b) )
           : ( (b < 0) && (INT128_MIN - a > b) ) ) ) overflow(aTHX_ add_error);
    if (SvOK(rev)) 
        RETVAL = newSVi128(aTHX_ a + b);
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) = a + b;
    }
OUTPUT:
    RETVAL

SV *
mi128_sub(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    int128_t a = SvI128x(self);
    int128_t b = SvI128(aTHX_ other);
CODE:
    if (SvTRUE(rev)) {
        int128_t tmp = a;
        a = b; b = tmp;
    }
    if ( may_die_on_overflow &&
         ( a > 0
           ? ( (b < 0) && (a - INT128_MAX > b) )
           : ( (b > 0) && (a - INT128_MIN < b) ) ) ) overflow(aTHX_ sub_error);
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ a - b);
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) = a - b;
    }
OUTPUT:
    RETVAL

SV *
mi128_mul(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    int128_t a1 = SvI128x(self);
    int128_t b1 = SvI128(aTHX_ other);
CODE:
    if (may_die_on_overflow) {
        int neg = 0;
        uint128_t a, b, rl, rh;
        if (a1 < 0) {
            a = -a1;
            neg ^= 1;
        }
        else a = a1;
        if (b1 < 0) {
            b = -b1;
            neg ^= 1;
        }
        else b = b1;
        if (a < b) {
            uint128_t tmp = a;
            a = b; b = tmp;
        }
        if (b > UINT64_MAX) overflow(aTHX_ mul_error);
        else {
            rl = (a & UINT64_MAX) * b;
            rh = (a >> 64) * b + (rl >> 64);
            if (rh > UINT64_MAX) overflow(aTHX_ mul_error);
        }
        if (a * b > (neg ? (~(uint128_t)INT128_MIN + 1) : INT128_MAX)) overflow(aTHX_ mul_error);
    }
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ a1 * b1);
    else {
        RETVAL = self;
        SvREFCNT_inc(RETVAL);
        SvI128x(self) = a1 * b1;
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
PREINIT:
    int128_t a;
    uint128_t b;
CODE:
    if (SvTRUE(rev)) {
        a = SvI128(aTHX_ other);
        b = SvU128x(self);
    }
    else {
        b = SvI128(aTHX_ other);
        a = SvU128x(self);
    }
    if (may_die_on_overflow && (b > 128)) overflow(aTHX_ left_error);
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ (b > 128 ? 0 : (a << b)));
    else {
        RETVAL = SvREFCNT_inc(self);
        SvI128x(self) = (b > 128 ? 0 : (a << b));
    }
OUTPUT:
    RETVAL

SV *mi128_right(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    int128_t a;
    uint128_t b;    
CODE:
    if (SvTRUE(rev)) {
        a = SvI128(aTHX_ other);
        b = SvU128x(self);
    }
    else {
        b = SvU128(aTHX_ other);
        a = SvI128x(self);
    }
    if (may_die_on_overflow && (b > 128)) overflow(aTHX_ right_error);
    if (SvOK(rev))
        RETVAL = newSVi128(aTHX_ a >> b);
    else {
        RETVAL = SvREFCNT_inc(self);
        SvI128x(self) = (a >> b);
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
    if (may_die_on_overflow && (SvU128x(self) == UINT128_MAX)) overflow(aTHX_ inc_error);
    SvU128x(self)++;
    RETVAL = SvREFCNT_inc(self);
OUTPUT:
    RETVAL

SV *
mu128_dec(self, other, rev)
    SV *self
    SV *other = NO_INIT
    SV *rev = NO_INIT
CODE:
    if (may_die_on_overflow && (SvU128x(self) == 0)) overflow(aTHX_ dec_error);
    SvU128x(self)--;
    RETVAL = SvREFCNT_inc(self);
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
PREINIT:
    uint128_t a, b;
CODE:
    if (SvTRUE(rev)) {
        a = SvU64(aTHX_ other);
        b = SvU64x(self);
    }
    else {
        a = SvU64x(self);
        b = SvU64(aTHX_ other);
    }
    if (may_die_on_overflow && (b > a)) overflow(aTHX_ sub_error);
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ a - b);
    else {
        RETVAL = SvREFCNT_inc(self);
        SvU128x(self) = a - b;
    }
OUTPUT:
    RETVAL

SV *
mu128_mul(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    uint128_t a = SvU128x(self);
    uint128_t b = SvU128(aTHX_ other);
CODE:
    if (may_die_on_overflow) {
        if (a < b) {
            uint128_t tmp = a;
            a = b; b = tmp;
        }
        if (b > UINT64_MAX) overflow(aTHX_ mul_error);
        else {
            uint128_t rl, rh;
            rl = (a & UINT64_MAX) * b;
            rh = (a >> 64) * b + (rl >> 64);
            if (rh > UINT64_MAX) overflow(aTHX_ mul_error);
        }
    }
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ a * b);
    else {
        RETVAL = SvREFCNT_inc(self);
        SvU128x(self) = a * b;
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
PREINIT:
    uint128_t a, b;
CODE:
    if (SvTRUE(rev)) {
        a = SvU128(aTHX_ other);
        b = SvU128x(self);
    }
    else {
        b = SvU128(aTHX_ other);
        a = SvU128x(self);
    }
    if ( may_die_on_overflow && (b > 128) ) overflow(aTHX_ left_b_error);
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ a << b);
    else {
        RETVAL = SvREFCNT_inc(self);
        SvU128x(self) = (a >> b);
    }
OUTPUT:
    RETVAL

SV *mu128_right(self, other, rev)
    SV *self
    SV *other
    SV *rev
PREINIT:
    uint128_t a, b;
CODE:
    if (SvTRUE(rev)) {
        a = SvU128(aTHX_ other);
        b = SvU128x(self);
    }
    else {
        b = SvU128(aTHX_ other);
        a = SvU128x(self);
    }
    if ( may_die_on_overflow && (b > 128) ) overflow(aTHX_ right_b_error);
    if (SvOK(rev))
        RETVAL = newSVu128(aTHX_ a >> b);
    }
    else {
        RETVAL = SvREFCNT_inc(self);
        SvU128x(self) = (a >> b);
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
