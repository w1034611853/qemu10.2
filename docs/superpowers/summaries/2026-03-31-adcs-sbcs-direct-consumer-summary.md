# ADCS/SBCS Direct Consumer Implementation Summary

## Overview

This line adds x86-host direct-consumer support for AArch64 `ADCS/SBCS`, but
only when the producer is already materialized and therefore leaves a live host
carry/borrow chain.

Supported direct paths:

- `ADDS rd,... -> ADCS`
- `SUBS rd,... -> SBCS`

Explicitly not supported as direct paths:

- `CMN -> ADCS`
- `CMP -> SBCS`

Those compare-like forms remain correct through fallback because they carry
`REWINDABLE_CMP` metadata rather than a materialized live host `CF`.

## Design State After Closure

### Producer model

- **Materialized producer**
  - `ADDS rd,...`
  - `SUBS rd,...`
  - leaves host carry/borrow live
  - can feed `ADCS/SBCS` directly

- **Rewindable producer**
  - `CMN`
  - `CMP`
  - carries delayed compare metadata only
  - must fall back for `ADCS/SBCS`

### Raw flags model

The direct helpers now do the full consumer-side state transition:

- emit host `adc/sbb`
- capture the consumer raw flags
- store them in `cpu_x86_raw_flags`
- set `A64_X86_CC_ADC64/ADC32/SBC64/SBC32`
- retire the pending producer

This fixes the earlier gap where the helper changed the raw-state tag but did
not write the actual consumer raw flags payload.

## Key Translator Changes

### `target/arm/tcg/translate-a64.c`

- `a64_insn_is_plain_adcs_reg()` and `a64_insn_is_plain_sbcs_reg()` identify
  `ADCS/SBCS`
- add/sub producer lookahead is now split by producer class
  - compare-like producers only look for plain `ADC/SBC`
  - materialized producers may look for `ADCS/SBCS`
- `a64_try_emit_x86_add_adcs()` handles setflags add-side direct consumption
- `a64_try_emit_x86_cmp_sbcs()` handles setflags sub-side direct consumption
- both helpers now capture consumer raw flags and clear `pending_cc`

## Test Coverage State

### `tests/tcg/aarch64/adc-sbc-host-direct.S`

Current coverage includes:

- materialized direct-path blocks
  - `ADDS64 -> ADCS64`
  - `ADDS32 -> ADCS32`
  - `SUBS64 -> SBCS64`
  - `SUBS32 -> SBCS32`
- imm/ext functional smoke blocks
  - `ADDS imm/ext -> ADCS`
  - `SUBS imm/ext -> SBCS`
- compare-like fallback blocks
  - `CMN -> ADCS`
  - `CMP -> SBCS`
- truly-adjacent compare-like negative blocks
  - `block_cmn_adcs64_adjacent`
  - `block_cmp_sbcs64_adjacent`

The truly-adjacent negative blocks now use opaque input loads so the compiler
cannot constant-fold away the producer/consumer shape under test.

### `tests/tcg/aarch64/nzcv-status4.S`

The new `0xaf` to `0xb2` cases now:

- keep producer and `ADCS/SBCS` truly adjacent
- verify both consumer result and post-consumer NZCV
- actually exercise the direct helper path instead of a nearby fallback shape

## Codegen Guard State

### `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

The guard is now split into two classes:

- **direct-path hard checks**
  - `ADDS64 -> ADCS64`
  - `ADDS32 -> ADCS32`
  - `SUBS64 -> SBCS64`
  - `SUBS32 -> SBCS32`

- **negative adjacent compare-like checks**
  - truly-adjacent `CMN -> ADCS` must show fallback carry seeding before the
    first consumer `adc`
  - truly-adjacent `CMP -> SBCS` must show fallback borrow seeding before the
    first consumer `sbb`

This closes the previous gap where the script could accidentally keep matching
older non-adjacent blocks and pass without validating the new narrowing.

## Verified Commands

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

## Final Behavioral Summary

| Producer -> Consumer | Current state | Notes |
|---|---|---|
| `ADDS64/32 -> ADCS64/32` | direct | materialized carry chain |
| `SUBS64/32 -> SBCS64/32` | direct | materialized borrow chain |
| `ADDS imm/ext -> ADCS` | direct, smoke-covered | no dedicated hard codegen oracle yet |
| `SUBS imm/ext -> SBCS` | direct, smoke-covered | no dedicated hard codegen oracle yet |
| `CMN -> ADCS` | fallback | `REWINDABLE_CMP` |
| `CMP -> SBCS` | fallback | `REWINDABLE_CMP` |
