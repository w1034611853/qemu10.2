#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

static const int64_t sdata[] = {
    17, -3, 42, -11, 9, 5, -23, 31,
    7, 7, -19, 13, 29, -2, 0, 18,
    -7, 61, -5, 27, 14, -9, 33, -15,
    8, -1, 55, -21, 3, 44, -13, 26,
};

static const double fdata[] = {
    1.5, -2.25, 3.75, -4.5, 5.25, -6.0, 7.125, -8.875,
};

static __attribute__((noinline)) uint64_t mix_aliases(int64_t x, int64_t y,
                                                      uint64_t acc)
{
    uint64_t cset = (x < y) ? 1u : 0u;
    uint64_t csetm = (x == y) ? UINT64_MAX : 0u;
    int64_t csneg = (x > y) ? x : -x;
    uint64_t csinc = (x <= y) ? (uint64_t)y : (uint64_t)(y + 1);
    uint64_t csinv = (x != y) ? (uint64_t)(~y) : (uint64_t)y;

    acc ^= cset * UINT64_C(0x9e3779b97f4a7c15);
    acc += csetm;
    acc ^= (uint64_t)csneg * 3;
    acc += csinc + csinv;
    return acc;
}

static __attribute__((noinline)) uint64_t mix_predicates(int64_t a, int64_t b,
                                                         int64_t c,
                                                         uint64_t acc)
{
    if ((a < b && b <= c) || (a == c)) {
        acc += (uint64_t)(a - b);
    } else if ((a > 0 && b < 0) || ((uint64_t)a < (uint64_t)c)) {
        acc ^= (uint64_t)(b - c);
    } else {
        acc += (uint64_t)(a ^ c);
    }

    acc += (a >= b) ? 11u : 7u;
    acc ^= (a > c) ? UINT64_C(0x13579bdf2468ace0)
                   : UINT64_C(0xfdb97531eca86420);
    return acc;
}

static __attribute__((noinline)) uint64_t mix_gap_branch(int64_t x, int64_t y,
                                                         uint64_t acc)
{
    uint64_t pred = x < y;

    acc += (acc << 3) ^ (acc >> 7);
    acc ^= UINT64_C(0x6a09e667f3bcc909);
    acc += (uint64_t)(x * 5 + y * 9);
    acc ^= UINT64_C(0xbb67ae8584caa73b);

    if (pred) {
        acc += UINT64_C(0x94d049bb133111eb);
    } else {
        acc ^= UINT64_C(0xdbe6d5d5fe4cce2f);
    }
    return acc;
}

static __attribute__((noinline)) uint64_t mix_fp_select(double a, double b,
                                                        int64_t x, int64_t y,
                                                        uint64_t acc)
{
    union {
        double d;
        uint64_t u;
    } bits;

    bits.d = (x < y) ? a : b;
    acc ^= bits.u;
    bits.d = (x == y) ? -a : b;
    acc += bits.u;
    return acc;
}

int main(void)
{
    uint64_t acc = UINT64_C(0x123456789abcdef0);
    size_t i;

    for (i = 0; i + 2 < sizeof(sdata) / sizeof(sdata[0]); i++) {
        acc = mix_aliases(sdata[i], sdata[i + 1], acc);
        acc = mix_predicates(sdata[i], sdata[i + 1], sdata[i + 2], acc);
        acc = mix_gap_branch(sdata[i + 1], sdata[i + 2], acc);
        acc = mix_fp_select(fdata[i & 7], fdata[(i + 3) & 7],
                            sdata[i], sdata[i + 1], acc);
    }

    printf("cmpstress-o3 0x%016" PRIx64 "\n", acc);
    return 0;
}
