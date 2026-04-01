# ADCS/SBCS Direct Consumer - Test Summary

## Scope

This test set validates the x86-host direct-consumer path for AArch64
`ADCS/SBCS`.

Current direct-support scope:

- `ADDS/SUBS -> ADCS/SBCS` when the producer is materialized

Current fallback scope:

- `CMN/CMP -> ADCS/SBCS`

## Test Environment

- Host: `x86_64`
- Target: `AArch64` via linux-user TCG
- QEMU binary: `build-aarch64-linux-user/qemu-aarch64`

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

- codegen guard: PASS
- functional test: exit code `0`
- semantic test: `PASS`

## Test Buckets

### 1. Functional assembly coverage

`tests/tcg/aarch64/adc-sbc-host-direct.S` exercises:

- materialized direct shapes
  - `ADDS64 -> ADCS64`
  - `ADDS32 -> ADCS32`
  - `SUBS64 -> SBCS64`
  - `SUBS32 -> SBCS32`
- imm/ext functional smoke cases
  - `ADDS imm/ext -> ADCS`
  - `SUBS imm/ext -> SBCS`
- compare-like fallback cases
  - `CMN -> ADCS`
  - `CMP -> SBCS`
- truly-adjacent compare-like negative cases
  - `block_cmn_adcs64_adjacent`
  - `block_cmp_sbcs64_adjacent`

The adjacent negative cases now load opaque inputs before the producer so the
compiler cannot fold the test into a different shape.

### 2. Codegen guard coverage

`tests/tcg/aarch64/check-adc-sbc-host-direct.sh` now explicitly validates:

| Path | Expected host shape | Status |
|---|---|---|
| `ADDS64 -> ADCS64` | `addq + adcq` with no decode glue | PASS |
| `ADDS32 -> ADCS32` | `addl + adcl` with no decode glue | PASS |
| `SUBS64 -> SBCS64` | `subq + sbbq` with no decode glue | PASS |
| `SUBS32 -> SBCS32` | `subl + sbbl` with no decode glue | PASS |
| adjacent `CMN -> ADCS` | fallback carry-seed before first consumer `adc` | PASS |
| adjacent `CMP -> SBCS` | fallback borrow-seed before first consumer `sbb` | PASS |

This is stronger than the previous version, which could accidentally keep
matching old non-adjacent blocks and pass without validating the new narrowing.

### 3. Semantic NZCV coverage

`tests/tcg/aarch64/nzcv-status4.S` covers:

- `0xab` to `0xae`
  - `ADCS/SBCS` as producers
- `0xaf` to `0xb2`
  - truly-adjacent materialized producer -> `ADCS/SBCS` consumer
  - verify both consumer result and post-consumer NZCV

The `0xaf` to `0xb2` cases now keep producer and consumer truly adjacent, so
they actually hit the direct helper path they are intended to validate.

## Behavioral Conclusions

### Direct path confirmed

- `ADDS64/32 -> ADCS64/32`
- `SUBS64/32 -> SBCS64/32`

### Fallback confirmed

- `CMN -> ADCS`
- `CMP -> SBCS`

The compare-like fallback is not merely functionally correct; the adjacent
negative blocks now prove that the translator is not incorrectly reusing the
materialized live-`CF` path there.

## Residual Coverage Note

The current focused hard codegen guard is strongest on reg-form 64/32
materialized direct paths.

imm/ext materialized `ADDS/SUBS -> ADCS/SBCS` are currently:

- functionally exercised
- architecturally smoke-covered

but they do not yet have their own dedicated hard codegen oracle.
