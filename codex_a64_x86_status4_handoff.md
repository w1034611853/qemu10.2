# ADCS/SBCS Direct Consumer - Handoff

## Repo / Branch
- Repo: `/home/wangruoyu/qemu10.2`
- Branch: `a64-x86-status4-v10.2.0`
- Context: AArch64-on-x86 TCG `ADCS/SBCS` direct-consumer optimization

## Status

**Current closure status: verified and ready to commit**

This round is no longer in the "fix found but test/docs still lag" state.
The implementation, focused tests, and codegen guard are now aligned.

## Confirmed Support Surface

### Plain consumer direct paths

These remain available and were not regressed by this round:

- `CMN / ADDS xzr,... -> ADC`
- `CMP / SUBS xzr,... -> SBC`
- `ADDS rd,... -> ADC`
- `SUBS rd,... -> SBC`

### Setflags consumer direct paths

These are the supported `ADCS/SBCS` direct-consumer paths after narrowing:

- `ADDS rd,... -> ADCS`
- `SUBS rd,... -> SBCS`

Current focused coverage includes:

- 64-bit and 32-bit reg-form direct cases
- imm/ext functional smoke cases
- consumer-after-read-NZCV cases in `nzcv-status4`

### Explicitly narrowed out of direct support

These now intentionally use fallback:

- `CMN -> ADCS`
- `CMP -> SBCS`

Reason:

- `CMN/CMP` produce `REWINDABLE_CMP`
- their carry/borrow is not a materialized live host `CF`
- the setflags direct helper is reserved for materialized producers only

## What Was Fixed In This Round

### 1. Compare-like `REWINDABLE_CMP` no longer leaks into `ADCS` direct path

`a64_try_emit_x86_add_adcs()` now accepts only `MATERIALIZED_ADD`.

### 2. `ADCS/SBCS` direct helpers now capture consumer raw flags

The direct helpers now:

- emit host `adc/sbb`
- capture the consumer's raw flags
- write them back to `cpu_x86_raw_flags`
- set the consumer raw state (`A64_X86_CC_ADC* / SBC*`)

### 3. `pending_cc` retirement / tracing is aligned

The setflags direct helpers now clear the pending producer consistently, and
`SBCS` tracing is no longer asymmetric with `ADCS`.

### 4. Test credibility gaps were fixed

- truly-adjacent compare-like negative blocks now use opaque input loads so the
  compiler cannot fold them away
- `nzcv-status4` cases `0xaf` to `0xb2` are now truly adjacent and actually hit
  the direct helper path they claim to cover
- the codegen guard uniquely targets the adjacent negative blocks and validates
  fallback carry/borrow seeding rather than matching the old non-adjacent blocks

## Verified Commands

Use linux-user artifacts, not `build/` softmmu binaries.

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
    adc-sbc-host-direct nzcv-status4

tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct

./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct

./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Observed result:

- `check-adc-sbc-host-direct.sh`: PASS
- `adc-sbc-host-direct`: exit code `0`
- `nzcv-status4`: `PASS`

## Files Touched In This Closure

- `target/arm/tcg/translate-a64.c`
- `tests/tcg/aarch64/adc-sbc-host-direct.S`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- `tests/tcg/aarch64/nzcv-status4.S`
- `docs/superpowers/summaries/2026-03-31-adcs-sbcs-direct-consumer-summary.md`
- `docs/superpowers/summaries/2026-03-31-adcs-sbcs-test-summary.md`

## Recommended Next Step

Two tracks remain after this commit:

1. Structural track: `lazy compare design` phase 2
2. Focused direct-path track: pick the next pairwise direct path

If you want to continue immediate feature work instead of design work, the most
reasonable user-selected kickoff target is:

- `ADDS/SUBS/ADCS/SBCS -> B.cond`
