> Archive: historical implementation plan kept for reference. The current
> merged state and remaining follow-up now live in `progress.md`.

# Lazy Compare Phase 2 B.cond Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the first semantic rollout of bounded lazy compare state for `B.cond`, with explicit gap-safe carry-across, invalidation, adjacency-precedence rules, and observable trace evidence.

**Architecture:** Reuse the existing `pending_cc` record and `A64_CMP_PENDING_GAP_MAX == 8`, but turn the current bounded-gap branch behavior into an explicit, tested, rollout-quality model. The first implementation slice is `B.cond` only, with the existing adjacent rewinding path kept as higher priority. A dedicated branch-gap harness plus `-d op,in_asm,out_asm` tracing will validate positive hits, invalidation, boundary drops, and record/consume/drop summaries.

**Tech Stack:** QEMU TCG, AArch64 translator, x86 host backend, AArch64 assembly regressions, shell codegen guard

## Execution Status

As of `2026-04-01`, the active worktree branch has already executed the first
rollout of this plan:

- `29f21e7534` `tests/aarch64: add lazy compare B.cond gap harness`
- `2464ce86a0` `tests/aarch64: tighten lazy compare gap invalidation coverage`
- `491e051771` `aarch64: make lazy compare B.cond lifetime explicit`
- `6653c87c86` `aarch64: extend lazy compare B.cond add-side coverage`
- `eece17cd54` `aarch64: extend add-like lazy B.cond jcc coverage`
- `05838b8e0a` `aarch64: chain ADCS xzr into lazy B.cond`

What is now true on that branch:

- bounded-gap `CMP/SUBS xzr -> B.cond` is implemented
- bounded-gap `CMN/ADDS xzr -> B.cond` is implemented
- add-side direct branch lowering currently stays within the TCG-mappable
  condition subset plus the x86-jcc-only family:
  - `EQ/NE/CS/CC/HI/LS/GE/LT/GT/LE`
  - `MI/PL/VS/VC`
- compare-like carry-add producer coverage now includes:
  - `ADCS xzr -> B.cond`
- page-boundary and direct-control-flow-cut invalidation are currently modeled
  conservatively as "producer declines to record", not "record then drop"

Deliberate deviation from the original adjacency wording:

- the stable branch tip validates adjacency as a direct `age=1` consume
- it does **not** currently insist on explicit `rewind` trace parity
- reintroducing the old rewind bookkeeping reopened the prior
  `temp_load: code should not be reached` runtime abort, so that part was
  deferred

Focused verification currently green on the worktree tip:

```bash
ninja -C build qemu-aarch64
tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/nzcv-status4
tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct
```

---

## File Map

| File | Responsibility |
|------|------|
| `target/arm/tcg/translate-a64.c` | Gap-safe whitelist reuse, `pending_cc` lifetime rules, consumer precedence, producer record/invalidation logic |
| `tests/tcg/aarch64/cmp-bcond-gap-host-direct.S` | Dedicated branch-gap functional coverage |
| `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh` | Codegen and trace oracle for gap hits and invalidation cases |
| `tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh` | Existing adjacent/ext guard kept as regression protection |
| `tests/tcg/aarch64/Makefile.target` | Build and run targets for the new branch-gap harness |
| `tests/tcg/aarch64/nzcv-status4.S` | Existing broad semantic regression that must stay green |

## Scope Lock

- First rollout target is `B.cond` only
- Keep current adjacent rewinding path higher priority than bounded gap
- Reuse current gap-safe whitelist exactly
- Reuse current bound exactly: `A64_CMP_PENDING_GAP_MAX == 8`
- No cross-TB support
- No floating-point compare path
- No changes to arithmetic direct-consumer support

---

### Task 1: Add Dedicated Gap-B.cond Red Tests

**Files:**
- Create: `tests/tcg/aarch64/cmp-bcond-gap-host-direct.S`
- Create: `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh`
- Modify: `tests/tcg/aarch64/Makefile.target`

- [ ] **Step 1: Create positive hit cases for both compare-like producer families**

In `cmp-bcond-gap-host-direct.S`, add at least:

- `CMP/SUBS xzr` with 1 safe gap
- `CMP/SUBS xzr` with 4 safe gaps
- `CMP/SUBS xzr` with 8 safe gaps
- `CMN/ADDS xzr` with 1 safe gap
- `CMN/ADDS xzr` with 4 safe gaps
- `CMN/ADDS xzr` with 8 safe gaps

Each case must:

- encode the producer
- encode exactly N gap-safe instructions
- use a concrete `B.cond`
- terminate via pass/fail labels and `svc #0`

- [ ] **Step 2: Add explicit invalidation cases**

Add at least:

- one non-whitelist instruction in the gap
- one flags writer in the gap
- one 9-gap case that exceeds the bound
- one boundary case that forces page/TB-end style drop
- one direct control-flow cut case

- [ ] **Step 3: Add one adjacency-precedence case**

Add a truly-adjacent producer/branch case that is already handled by the current
adjacent rewinding path. The dedicated harness must keep this case so we can
prove the new bounded-gap path does not steal precedence.

- [ ] **Step 4: Create `check-cmp-bcond-gap-host-direct.sh`**

The script should:

- run QEMU with `-d op,in_asm,out_asm,nochain`
- locate each test block
- assert that positive hit cases produce direct host compare/branch lowering
- assert that invalidation cases do not claim the new path
- assert concrete `cmp-pending` trace markers for:
  - record
  - consume
  - drop
  - summary

- [ ] **Step 5: Wire the new test into `Makefile.target`**

Add:

- target build rule
- run target following the `run-cmp-bcond-ext-host-direct-codegen` pattern

- [ ] **Step 6: Build the new harness and verify it is red before implementation**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
    cmp-bcond-gap-host-direct
tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
```

Expected:

- at least one positive gap-hit check is red on the current tree

- [ ] **Step 7: Commit the red harness**

```bash
git add tests/tcg/aarch64/cmp-bcond-gap-host-direct.S \
        tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
        tests/tcg/aarch64/Makefile.target
git commit -m "tests/aarch64: add lazy compare B.cond gap harness"
```

---

### Task 2: Make Gap-Safe / Invalidation Rules Explicit In Code

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: Audit the current gap-safe helpers and lifetime logic**

Read:

- `a64_insn_is_cmp_gap_safe()`
- `a64_find_future_bcond_gap()`
- `a64_record_cmp_for_bcond()`
- `a64_try_emit_x86_cmp_bcond()`
- end-of-insn `keep/gap_insns` handling

- [ ] **Step 2: Make bound handling explicit**

Implement or tighten:

- `gap_insns` initialization
- decrement on every whitelist instruction crossed
- immediate drop after the bound is exhausted

Keep the bound fixed at `8`.

- [ ] **Step 3: Make invalidation triggers explicit**

Drop the record on:

- flags writers
- non-whitelist instructions
- page crossing
- TB instruction limit / end
- direct control-flow cut

- [ ] **Step 4: Preserve adjacent precedence**

Keep the rule:

- if the current pair qualifies for the existing adjacent rewinding fast path,
  that path wins first
- bounded-gap logic only handles non-adjacent but still in-bound cases

- [ ] **Step 5: Re-run the red harness**

Run the command set from Task 1, Step 6.

Expected:

- failures should narrow to missing producer coverage rather than lifetime bugs

- [ ] **Step 6: Commit lifetime/invalidation work**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: make lazy compare B.cond lifetime explicit"
```

---

### Task 3: Extend Producer Coverage For The B.cond Rollout

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`
- Modify: `tests/tcg/aarch64/cmp-bcond-gap-host-direct.S`
- Modify: `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh`

- [ ] **Step 1: Audit current producer entry points**

Check which sites already call `a64_find_future_bcond_gap()` and which producer
families are still missing from the bounded-gap branch path.

- [ ] **Step 2: Add the missing branch-gap record hooks for both compare-like halves**

The rollout target here is the full compare-like producer set required by the
spec:

- `CMP/SUBS xzr`
- `CMN/ADDS xzr`

Extend producer-side record logic where needed so the dedicated gap harness can
go green without widening the scope lock.

- [ ] **Step 3: Keep the whitelist exact**

Do not widen the gap-safe opcode set while extending producer coverage.

- [ ] **Step 4: Update the gap harness if one producer family needs a more stable branch condition**

If implementation details force a different concrete condition code for one of
the positive hit cases, update the test file and shell oracle together.

- [ ] **Step 5: Re-run the new gap harness**

Run:

```bash
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
    cmp-bcond-gap-host-direct
tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
```

Expected:

- positive gap-hit cases pass for both compare-like halves
- invalidation cases stay correct

- [ ] **Step 6: Commit producer-coverage changes**

```bash
git add target/arm/tcg/translate-a64.c \
        tests/tcg/aarch64/cmp-bcond-gap-host-direct.S \
        tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh
git commit -m "aarch64: extend lazy compare B.cond producer coverage"
```

---

### Task 4: Preserve Existing Regression Protections

**Files:**
- Modify: `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh` (if needed)
- Test: `tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh`
- Test: `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

- [ ] **Step 1: Rebuild prerequisite branch and arithmetic tests**

```bash
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
    cmp-bcond-gap-host-direct \
    cmp-bcond-ext-host-direct \
    adc-sbc-host-direct \
    nzcv-status4
```

- [ ] **Step 2: Run the existing ext adjacent branch guard**

```bash
tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct
```

Expected: PASS

- [ ] **Step 3: Re-run the arithmetic direct-consumer guard**

```bash
tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

Expected: PASS

- [ ] **Step 4: Re-run `nzcv-status4`**

```bash
./build-aarch64-linux-user/qemu-aarch64 \
    -cpu max \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected: PASS

- [ ] **Step 5: Commit any oracle cleanups**

```bash
git add tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh
git commit -m "tests/aarch64: lock lazy compare B.cond regressions"
```

---

### Task 5: Final Verification

**Files:**
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **Step 1: Rebuild the binary and branch tests**

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
    cmp-bcond-gap-host-direct cmp-bcond-ext-host-direct nzcv-status4
```

- [ ] **Step 2: Run the new gap codegen-and-trace guard**

```bash
tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
```

Expected: PASS

- [ ] **Step 3: Run the dedicated gap functional test**

```bash
./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
```

Expected: exit code `0`

- [ ] **Step 4: Re-run the existing adjacent/ext guard**

```bash
tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct
```

Expected: PASS

- [ ] **Step 5: Re-run `nzcv-status4`**

```bash
./build-aarch64-linux-user/qemu-aarch64 \
    -cpu max \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected: PASS

- [ ] **Step 6: Commit final rollout changes**

```bash
git add target/arm/tcg/translate-a64.c \
        tests/tcg/aarch64/cmp-bcond-gap-host-direct.S \
        tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
        tests/tcg/aarch64/Makefile.target
git commit -m "aarch64: roll out lazy compare B.cond phase 2"
```
