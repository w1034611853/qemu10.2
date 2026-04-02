> Archive: historical implementation plan kept for reference. Current merged
> status and follow-up notes now live in `progress.md`.

# ADCS/SBCS Producer Direct Consumer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend same-TB adjacent arithmetic chaining so materialized `ADCS/SBCS` can directly feed the next `ADC/SBC/ADCS/SBCS`, with phase A1 landing plain consumers first and phase A2 landing setflags consumers.

**Architecture:** Reuse the existing materialized producer model rather than inventing a new producer kind. `ADCS/SBCS` become new materialized producers by recording `A64_X86_CC_ADC* / SBC*` in `pending_cc`, then the consumer helpers widen their acceptance from `ADD/SUB` to `ADD/ADC` or `SUB/SBC` as appropriate. Keep `rd != 31`, same-width only, and preserve the existing `SBCS xzr -> future B.cond` priority.

**Tech Stack:** QEMU TCG, AArch64 translator, x86 host backend, AArch64 assembly regressions, shell codegen guard

---

## File Map

| File | Responsibility |
|------|------|
| `target/arm/tcg/translate-a64.c` | Producer recording after `ADCS/SBCS`, helper widening, `SBCS xzr -> B.cond` priority preservation |
| `tests/tcg/aarch64/adc-sbc-host-direct.S` | Focused adjacency tests for `ADCS/SBCS` as producers |
| `tests/tcg/aarch64/check-adc-sbc-host-direct.sh` | Hard codegen and negative-fallback oracles for `ADCS/SBCS -> ADC/SBC/ADCS/SBCS` |
| `tests/tcg/aarch64/nzcv-status4.S` | Semantic checks for plain-consumer flags preservation and setflags-consumer flag replacement |

## Scope Lock

- Same-TB only
- Truly-adjacent producer/consumer only
- x86 host only
- same-width chaining only
  - `64 -> 64`
  - `32 -> 32`
- `rd != 31` only
- No `CMN/CMP -> ADCS/SBCS`
- No branch work in this plan

---

### Task 1: Write Failing Tests For Phase A1 (`ADCS/SBCS -> ADC/SBC`)

**Files:**
- Modify: `tests/tcg/aarch64/adc-sbc-host-direct.S`
- Modify: `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- Modify: `tests/tcg/aarch64/nzcv-status4.S`

- [ ] **Step 1: Add truly-adjacent phase A1 blocks to `adc-sbc-host-direct.S`**

Add at least:

- `block_adcs_adc64`
- `block_adcs_adc32`
- `block_sbcs_sbc64`
- `block_sbcs_sbc32`

Use explicit carry/borrow seed setup before the producer, but keep producer and
plain consumer truly adjacent.

- [ ] **Step 2: Add matching `bl` call sites in `_start`**

Wire every new phase A1 block into `_start`, otherwise the new blocks will not
execute and will never appear in `out_asm`.

- [ ] **Step 3: Add one mixed-width negative block and wire it into `_start`**

Add one smoke block such as:

- `ADCS32 -> ADC64`
or
- `SBCS64 -> SBC32`

This block must execute, but it must remain outside the direct-path support
surface.

- [ ] **Step 4: Extend `check-adc-sbc-host-direct.sh` with new extractors**

Add block extraction for:

- `ADCS64 -> ADC64`
- `ADCS32 -> ADC32`
- `SBCS64 -> SBC64`
- `SBCS32 -> SBC32`
- the mixed-width negative case

- [ ] **Step 5: Add hard codegen checks for same-width phase A1 direct paths**

Require:

- add-side:
  - consumer block shows `adcq` or `adcl`
  - no carry-decode glue between producer and consumer
- sub-side:
  - consumer block shows `sbbq` or `sbbl`
  - no borrow-decode glue between producer and consumer

Allow producer raw-state restoration after the plain consumer, because that is
the intended phase A1 behavior.

- [ ] **Step 6: Add a negative oracle for the mixed-width block**

The mixed-width block should:

- remain functionally correct
- not claim the compact supported same-width direct shape

This closes the gap where a mixed-width widening could silently slip in.

- [ ] **Step 7: Add semantic cases to `nzcv-status4.S` for flags preservation**

Add at least:

- `ADCS64 -> ADC64 -> MRS NZCV`
- `SBCS64 -> SBC64 -> MRS NZCV`
- `ADCS32 -> ADC32 -> MRS NZCV`
- `SBCS32 -> SBC32 -> MRS NZCV`

Choose operands so producer flags and consumer flags are deliberately different.
Each case must verify:

- the plain consumer result
- the final NZCV still matches the producer (`ADCS/SBCS`)

- [ ] **Step 8: Run the focused tests to verify phase A1 is red before implementation**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
    adc-sbc-host-direct nzcv-status4
tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
./build-aarch64-linux-user/qemu-aarch64 \
    -cpu max \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- at least one new phase A1 check fails on the current tree

- [ ] **Step 9: Commit the red tests**

```bash
git add tests/tcg/aarch64/adc-sbc-host-direct.S \
        tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
        tests/tcg/aarch64/nzcv-status4.S
git commit -m "tests/aarch64: expose ADCS/SBCS producer plain-consumer gaps"
```

---

### Task 2: Implement Phase A1 Producer Recording And Plain-Consumer Support

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: Audit current `do_adc_sbc()` control flow**

Identify where `ADCS/SBCS` currently return early as consumers, and where that
prevents the same instruction from becoming the producer for the next
instruction.

- [ ] **Step 2: Refactor `do_adc_sbc()` so execution and producer-recording are separable**

Do not return immediately after a successful `ADCS/SBCS` direct helper if the
current instruction may need to be recorded as the next producer.

- [ ] **Step 3: Add lookahead for phase A1 plain consumers after `ADCS/SBCS`**

For current `ADCS`:

- next plain `ADC` should trigger add-side producer recording

For current `SBCS`:

- next plain `SBC` should trigger sub-side producer recording

Restrict to:

- same-width only
- `rd != 31`

- [ ] **Step 4: Record `ADCS/SBCS` as materialized producers**

Record:

- `kind = MATERIALIZED_ADD` for `ADCS`
- `kind = MATERIALIZED_SUB` for `SBCS`
- `cc_op = A64_X86_CC_ADC64/ADC32` or `A64_X86_CC_SBC64/SBC32`

- [ ] **Step 5: Widen `a64_try_emit_x86_add_adc()` acceptance**

Allow add-side producer `cc_op`:

- `ADD64/32`
- `ADC64/32`

- [ ] **Step 6: Widen `a64_try_emit_x86_cmp_sbc()` acceptance**

Allow sub-side producer `cc_op`:

- `SUB64/32`
- `SBC64/32`

- [ ] **Step 7: Preserve plain-consumer post-state rules**

Verify:

- plain `ADC/SBC` still restore producer raw-state
- they do not leave the consumer as the final architectural flags producer

- [ ] **Step 8: Preserve `SBCS xzr -> future B.cond` priority**

Ensure:

- `rd == 31` never enters the new chaining path
- current `lazy_bcond_cmp` behavior is unchanged

- [ ] **Step 9: Run focused verification for phase A1**

Run:

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
    -cpu max \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- phase A1 tests pass
- existing `ADDS/SUBS -> ADCS/SBCS` tests remain green

- [ ] **Step 10: Commit phase A1**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: chain ADCS/SBCS into plain ADC/SBC"
```

---

### Task 3: Write Failing Tests For Phase A2 (`ADCS/SBCS -> ADCS/SBCS`)

**Files:**
- Modify: `tests/tcg/aarch64/adc-sbc-host-direct.S`
- Modify: `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- Modify: `tests/tcg/aarch64/nzcv-status4.S`

- [ ] **Step 1: Add truly-adjacent phase A2 blocks and wire them into `_start`**

Add and call:

- `block_adcs_adcs64`
- `block_adcs_adcs32`
- `block_sbcs_sbcs64`
- `block_sbcs_sbcs32`

- [ ] **Step 2: Add explicit phase A2 extractor plumbing to the shell guard**

Before writing assertions, add:

- cleanup for new temp files
- per-block extraction
- extraction failure diagnostics

for all four phase A2 blocks.

- [ ] **Step 3: Add phase A2 hard codegen checks**

Require:

- add-side chain: producer/consumer stays in `adcq/adcl`
- sub-side chain: producer/consumer stays in `sbbq/sbbl`
- no carry/borrow decode glue appears between producer and consumer

- [ ] **Step 4: Add semantic cases to `nzcv-status4.S` for consumer-owned flags**

Add at least:

- `ADCS64 -> ADCS64 -> MRS NZCV`
- `SBCS64 -> SBCS64 -> MRS NZCV`
- `ADCS32 -> ADCS32 -> MRS NZCV`
- `SBCS32 -> SBCS32 -> MRS NZCV`

Each case must verify:

- final result
- final NZCV belongs to the second instruction, not the first

- [ ] **Step 5: Run the focused tests to verify phase A2 is red before implementation**

Reuse the focused command set from Task 1, Step 8.

Expected:

- phase A2 checks fail on the phase-A1-only tree

- [ ] **Step 6: Commit the red tests**

```bash
git add tests/tcg/aarch64/adc-sbc-host-direct.S \
        tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
        tests/tcg/aarch64/nzcv-status4.S
git commit -m "tests/aarch64: expose ADCS/SBCS chain gaps"
```

---

### Task 4: Implement Phase A2 Setflags-Consumer Chaining

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: Extend producer lookahead after `ADCS/SBCS` to setflags consumers**

Allow:

- `ADCS -> ADCS`
- `SBCS -> SBCS`

Still keep:

- same-width only
- `rd != 31`

- [ ] **Step 2: Widen `a64_try_emit_x86_add_adcs()` acceptance**

Allow producer `cc_op`:

- `ADD64/32`
- `ADC64/32`

- [ ] **Step 3: Widen `a64_try_emit_x86_cmp_sbcs()` acceptance**

Allow producer `cc_op`:

- `SUB64/32`
- `SBC64/32`

- [ ] **Step 4: Preserve setflags-consumer post-state rules**

Verify:

- consumer raw-state wins
- producer raw-state is not restored
- current direct helpers still capture the final consumer raw flags

- [ ] **Step 5: Re-run focused verification**

Run the same focused command set as Task 2, Step 9.

Expected:

- phase A1 and phase A2 tests both pass

- [ ] **Step 6: Commit phase A2**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: chain ADCS/SBCS into ADCS/SBCS"
```

---

### Task 5: Final Verification

**Files:**
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **Step 1: Rebuild the binary and test artifacts**

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
    adc-sbc-host-direct nzcv-status4
```

- [ ] **Step 2: Run the codegen guard**

```bash
tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

Expected: PASS

- [ ] **Step 3: Run the functional direct-path test**

```bash
./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

Expected: exit code `0`

- [ ] **Step 4: Run the semantic NZCV test**

```bash
./build-aarch64-linux-user/qemu-aarch64 \
    -cpu max \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected: `PASS`

- [ ] **Step 5: Commit any final touch-ups**

```bash
git add target/arm/tcg/translate-a64.c \
        tests/tcg/aarch64/adc-sbc-host-direct.S \
        tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
        tests/tcg/aarch64/nzcv-status4.S
git commit -m "aarch64: finalize ADCS/SBCS producer direct-consumer support"
```
