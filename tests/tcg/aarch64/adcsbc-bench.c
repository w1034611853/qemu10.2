#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const uint64_t data64[] = {
    UINT64_C(0x0123456789abcdef), UINT64_C(0xfedcba9876543210),
    UINT64_C(0x13579bdf2468ace0), UINT64_C(0x0f0e0d0c0b0a0908),
    UINT64_C(0x1122334455667788), UINT64_C(0x8877665544332211),
    UINT64_C(0xdeadbeefcafebabe), UINT64_C(0x3141592653589793),
    UINT64_C(0x2718281828459045), UINT64_C(0xaaaaaaaa55555555),
    UINT64_C(0x55aa55aa33cc33cc), UINT64_C(0x1234123412341234),
    UINT64_C(0xffff0000ffff0000), UINT64_C(0x0000ffff0000ffff),
    UINT64_C(0x7fffffffffffffff), UINT64_C(0x8000000000000001),
};

static const uint32_t data32[] = {
    UINT32_C(0x89abcdef), UINT32_C(0x76543210),
    UINT32_C(0x2468ace0), UINT32_C(0x0b0a0908),
    UINT32_C(0x55667788), UINT32_C(0x44332211),
    UINT32_C(0xcafebabe), UINT32_C(0x53589793),
    UINT32_C(0x28459045), UINT32_C(0x55555555),
    UINT32_C(0x33cc33cc), UINT32_C(0x12341234),
    UINT32_C(0xffff0000), UINT32_C(0x0000ffff),
    UINT32_C(0x7fffffff), UINT32_C(0x80000001),
};

static __attribute__((noinline)) uint64_t bench_adc64(uint64_t iters)
{
    uint64_t acc = UINT64_C(0x123456789abcdef0);
    uint64_t lhs = UINT64_C(0x9e3779b97f4a7c15);
    uint64_t rhs = UINT64_C(0x6a09e667f3bcc909);

    for (uint64_t i = 0; i < iters; i++) {
        uint64_t v = data64[i & 15];

        asm volatile(
            "cmp %x[lhs], %x[rhs]\n\t"
            "adc %x[acc], %x[acc], %x[v]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs += v ^ (acc >> 7);
        rhs ^= (v << 9) + acc;
    }
    return acc ^ lhs ^ (rhs << 1);
}

static __attribute__((noinline)) uint64_t bench_cmnadc64(uint64_t iters)
{
    uint64_t acc = UINT64_C(0x123456789abcdef0);
    uint64_t lhs = UINT64_C(0x9e3779b97f4a7c15);
    uint64_t rhs = UINT64_C(0x6a09e667f3bcc909);

    for (uint64_t i = 0; i < iters; i++) {
        uint64_t v = data64[i & 15];

        asm volatile(
            "cmn %x[lhs], %x[rhs]\n\t"
            "adc %x[acc], %x[acc], %x[v]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs += v ^ (acc >> 7);
        rhs ^= (v << 9) + acc;
    }
    return acc ^ lhs ^ (rhs << 1);
}

static __attribute__((noinline)) uint64_t bench_addsadc64(uint64_t iters)
{
    uint64_t acc = UINT64_C(0x123456789abcdef0);
    uint64_t lhs = UINT64_C(0x9e3779b97f4a7c15);
    uint64_t rhs = UINT64_C(0x6a09e667f3bcc909);
    uint64_t sum = 0;

    for (uint64_t i = 0; i < iters; i++) {
        uint64_t v = data64[i & 15];

        asm volatile(
            "adds %x[sum], %x[lhs], %x[rhs]\n\t"
            "adc %x[acc], %x[acc], %x[v]\n\t"
            : [sum]"=&r"(sum), [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs = sum + (v ^ (acc >> 7));
        rhs ^= (v << 9) + sum;
    }
    return acc ^ lhs ^ (rhs << 1) ^ (sum >> 3);
}

static __attribute__((noinline)) uint64_t bench_sbc64(uint64_t iters)
{
    uint64_t acc = UINT64_C(0xfedcba9876543210);
    uint64_t lhs = UINT64_C(0x243f6a8885a308d3);
    uint64_t rhs = UINT64_C(0x13198a2e03707344);

    for (uint64_t i = 0; i < iters; i++) {
        uint64_t v = data64[i & 15];

        asm volatile(
            "cmp %x[lhs], %x[rhs]\n\t"
            "sbc %x[acc], %x[acc], %x[v]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs ^= v + acc;
        rhs += (v >> 3) ^ (acc << 1);
    }
    return acc ^ (lhs << 1) ^ rhs;
}

static __attribute__((noinline)) uint64_t bench_subssbc64(uint64_t iters)
{
    uint64_t acc = UINT64_C(0xfedcba9876543210);
    uint64_t lhs = UINT64_C(0x243f6a8885a308d3);
    uint64_t rhs = UINT64_C(0x13198a2e03707344);
    uint64_t diff = 0;

    for (uint64_t i = 0; i < iters; i++) {
        uint64_t v = data64[i & 15];

        asm volatile(
            "subs %x[diff], %x[lhs], %x[rhs]\n\t"
            "sbc %x[acc], %x[acc], %x[v]\n\t"
            : [diff]"=&r"(diff), [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs = diff ^ (v + acc);
        rhs += (v >> 3) ^ (diff << 1);
    }
    return acc ^ (lhs << 1) ^ rhs ^ (diff >> 5);
}

static __attribute__((noinline)) uint64_t bench_adcsbc64(uint64_t iters)
{
    uint64_t acc = UINT64_C(0x0badf00ddeadbeef);
    uint64_t lhs = UINT64_C(0xa4093822299f31d0);
    uint64_t rhs = UINT64_C(0x082efa98ec4e6c89);

    for (uint64_t i = 0; i < iters; i++) {
        uint64_t a = data64[i & 15];
        uint64_t b = data64[(i + 5) & 15];

        asm volatile(
            "cmp %x[lhs], %x[rhs]\n\t"
            "adc %x[acc], %x[acc], %x[a]\n\t"
            "cmp %x[rhs], %x[lhs]\n\t"
            "sbc %x[acc], %x[acc], %x[b]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [a]"r"(a), [b]"r"(b)
            : "cc");

        lhs += a ^ acc;
        rhs ^= b + (acc >> 11);
    }
    return acc ^ lhs ^ rhs;
}

static __attribute__((noinline)) uint64_t bench_adc32(uint64_t iters)
{
    uint32_t acc = UINT32_C(0x89abcdef);
    uint32_t lhs = UINT32_C(0x7f4a7c15);
    uint32_t rhs = UINT32_C(0xf3bcc909);

    for (uint64_t i = 0; i < iters; i++) {
        uint32_t v = data32[i & 15];

        asm volatile(
            "cmp %w[lhs], %w[rhs]\n\t"
            "adc %w[acc], %w[acc], %w[v]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs += v ^ (acc >> 5);
        rhs ^= (v << 7) + acc;
    }
    return (uint64_t)acc ^ ((uint64_t)lhs << 32) ^ rhs;
}

static __attribute__((noinline)) uint64_t bench_cmnadc32(uint64_t iters)
{
    uint32_t acc = UINT32_C(0x89abcdef);
    uint32_t lhs = UINT32_C(0x7f4a7c15);
    uint32_t rhs = UINT32_C(0xf3bcc909);

    for (uint64_t i = 0; i < iters; i++) {
        uint32_t v = data32[i & 15];

        asm volatile(
            "cmn %w[lhs], %w[rhs]\n\t"
            "adc %w[acc], %w[acc], %w[v]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs += v ^ (acc >> 5);
        rhs ^= (v << 7) + acc;
    }
    return (uint64_t)acc ^ ((uint64_t)lhs << 32) ^ rhs;
}

static __attribute__((noinline)) uint64_t bench_addsadc32(uint64_t iters)
{
    uint32_t acc = UINT32_C(0x89abcdef);
    uint32_t lhs = UINT32_C(0x7f4a7c15);
    uint32_t rhs = UINT32_C(0xf3bcc909);
    uint32_t sum = 0;

    for (uint64_t i = 0; i < iters; i++) {
        uint32_t v = data32[i & 15];

        asm volatile(
            "adds %w[sum], %w[lhs], %w[rhs]\n\t"
            "adc %w[acc], %w[acc], %w[v]\n\t"
            : [sum]"=&r"(sum), [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs = sum + (v ^ (acc >> 5));
        rhs ^= (v << 7) + sum;
    }
    return (uint64_t)acc ^ ((uint64_t)lhs << 32) ^ rhs ^ ((uint64_t)sum << 17);
}

static __attribute__((noinline)) uint64_t bench_sbc32(uint64_t iters)
{
    uint32_t acc = UINT32_C(0x76543210);
    uint32_t lhs = UINT32_C(0x85a308d3);
    uint32_t rhs = UINT32_C(0x03707344);

    for (uint64_t i = 0; i < iters; i++) {
        uint32_t v = data32[i & 15];

        asm volatile(
            "cmp %w[lhs], %w[rhs]\n\t"
            "sbc %w[acc], %w[acc], %w[v]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs ^= v + acc;
        rhs += (v >> 2) ^ (acc << 1);
    }
    return (uint64_t)acc ^ ((uint64_t)lhs << 32) ^ rhs;
}

static __attribute__((noinline)) uint64_t bench_subssbc32(uint64_t iters)
{
    uint32_t acc = UINT32_C(0x76543210);
    uint32_t lhs = UINT32_C(0x85a308d3);
    uint32_t rhs = UINT32_C(0x03707344);
    uint32_t diff = 0;

    for (uint64_t i = 0; i < iters; i++) {
        uint32_t v = data32[i & 15];

        asm volatile(
            "subs %w[diff], %w[lhs], %w[rhs]\n\t"
            "sbc %w[acc], %w[acc], %w[v]\n\t"
            : [diff]"=&r"(diff), [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [v]"r"(v)
            : "cc");

        lhs = diff ^ (v + acc);
        rhs += (v >> 2) ^ (diff << 1);
    }
    return (uint64_t)acc ^ ((uint64_t)lhs << 32) ^ rhs ^
           ((uint64_t)diff << 11);
}

static __attribute__((noinline)) uint64_t bench_adcsbc32(uint64_t iters)
{
    uint32_t acc = UINT32_C(0xdeadbeef);
    uint32_t lhs = UINT32_C(0x299f31d0);
    uint32_t rhs = UINT32_C(0xec4e6c89);

    for (uint64_t i = 0; i < iters; i++) {
        uint32_t a = data32[i & 15];
        uint32_t b = data32[(i + 7) & 15];

        asm volatile(
            "cmp %w[lhs], %w[rhs]\n\t"
            "adc %w[acc], %w[acc], %w[a]\n\t"
            "cmp %w[rhs], %w[lhs]\n\t"
            "sbc %w[acc], %w[acc], %w[b]\n\t"
            : [acc]"+r"(acc)
            : [lhs]"r"(lhs), [rhs]"r"(rhs), [a]"r"(a), [b]"r"(b)
            : "cc");

        lhs += a ^ acc;
        rhs ^= b + (acc >> 9);
    }
    return (uint64_t)acc ^ ((uint64_t)lhs << 32) ^ rhs;
}

static uint64_t run_mode(const char *mode, uint64_t iters)
{
    if (strcmp(mode, "adc64") == 0) {
        return bench_adc64(iters);
    }
    if (strcmp(mode, "cmnadc64") == 0) {
        return bench_cmnadc64(iters);
    }
    if (strcmp(mode, "addsadc64") == 0) {
        return bench_addsadc64(iters);
    }
    if (strcmp(mode, "sbc64") == 0) {
        return bench_sbc64(iters);
    }
    if (strcmp(mode, "subsbc64") == 0) {
        return bench_subssbc64(iters);
    }
    if (strcmp(mode, "adcsbc64") == 0) {
        return bench_adcsbc64(iters);
    }
    if (strcmp(mode, "adc32") == 0) {
        return bench_adc32(iters);
    }
    if (strcmp(mode, "cmnadc32") == 0) {
        return bench_cmnadc32(iters);
    }
    if (strcmp(mode, "addsadc32") == 0) {
        return bench_addsadc32(iters);
    }
    if (strcmp(mode, "sbc32") == 0) {
        return bench_sbc32(iters);
    }
    if (strcmp(mode, "subsbc32") == 0) {
        return bench_subssbc32(iters);
    }
    if (strcmp(mode, "adcsbc32") == 0) {
        return bench_adcsbc32(iters);
    }

    fprintf(stderr, "unknown mode: %s\n", mode);
    exit(2);
}

int main(int argc, char **argv)
{
    static const char *const modes[] = {
        "adc64", "cmnadc64", "addsadc64", "sbc64", "subsbc64", "adcsbc64",
        "adc32", "cmnadc32", "addsadc32", "sbc32", "subsbc32", "adcsbc32",
    };

    if (argc == 1) {
        const uint64_t iters = 4096;

        for (size_t i = 0; i < sizeof(modes) / sizeof(modes[0]); i++) {
            printf("adcsbc-bench %s 0x%016" PRIx64 "\n",
                   modes[i], run_mode(modes[i], iters));
        }
        return 0;
    }

    if (argc == 3) {
        uint64_t iters = strtoull(argv[2], NULL, 0);
        printf("adcsbc-bench %s 0x%016" PRIx64 "\n",
               argv[1], run_mode(argv[1], iters));
        return 0;
    }

    fprintf(stderr, "usage: %s [mode iterations]\n", argv[0]);
    return 2;
}
