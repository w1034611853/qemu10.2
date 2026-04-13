# Deferred Flags Main Representation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current miss-sensitive NZCV sidecar model with a durable `RAW/SPLIT` main-representation model that preserves same-TB live-host wins while pulling miss-case behavior back toward clean upstream QEMU.

**Architecture:** Keep `LIVE_HOST` as a same-TB opportunistic fast path only. Promote two durable flags representations to first-class state: `DEFERRED_RAW = raw_flags + cc_op` for x86-friendly producers and `DEFERRED_SPLIT = CF/VF/NF/ZF proxy` for split-only producers. Specialize TB entry on `RAW/SPLIT`, let the translator update representation at translation time, and route `B.cond`, `CSEL*`, and `ADC/SBC` through the current main representation instead of pairwise `pending_cc` dependence.

**Tech Stack:** QEMU AArch64 TCG frontend, x86 TCG backend, AArch64 TCG assembly regressions, focused codegen checkers, local smoke/perf probes, Git

---

## File Map

| File | Responsibility |
|------|------|
| `target/arm/cpu.h` | Define durable flags-representation state and env fields used across TBs |
| `target/arm/tcg/translate.c` | Expose any new global TCG env fields for flags representation payload |
| `target/arm/tcg/hflags.c` | Encode and decode TB entry representation tag in A64 TBFLAGS |
| `target/arm/tcg/translate-a64.c` | Main implementation: representation tracking, producer routing, consumer lowering, fallback cleanup |
| `tests/tcg/aarch64/nzcv-status4.S` | Architectural regressions for cross-TB persistence, `RAW -> SPLIT` downgrade, and explicit NZCV materialization |
| `tests/tcg/aarch64/cmp-bcond-gap-host-direct.S` | Focused branch consumer harness for raw-main-representation behavior |
| `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh` | Codegen/debug oracle for branch consumer hot path |
| `tests/tcg/aarch64/cmp-csel-gap-host-direct.S` | Focused conditional-select consumer harness |
| `tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh` | Codegen/debug oracle for `CSEL*` consumer path |
| `tests/tcg/aarch64/adc-sbc-host-direct.S` | Focused carry-consumer harness for `ADC/SBC` behavior |
| `tests/tcg/aarch64/check-adc-sbc-host-direct.sh` | Codegen/debug oracle for carry-only consumer path |
| `progress.md` | Record new main-representation model, rollout boundary, and verification outcome |

## Task 1: Add Red Architectural Regressions for Main-Representation Semantics

**Files:**
- Modify: `tests/tcg/aarch64/nzcv-status4.S`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **Step 1: Add a cross-TB `RAW` persistence regression**

Add one case shaped like:

```asm
cmp     x0, x1
b       1f
1:
    b.eq    ok
    b       fail
```

The point is: a raw-friendly producer must survive a TB cut even when `LIVE_HOST`
cannot.

- [ ] **Step 2: Add a `RAW -> SPLIT` downgrade regression**

Add one case shaped like:

```asm
cmp     x0, x1
cfinv
b.cc    ok
```

or an equivalent split-only producer path such as explicit `MSR NZCV`. The point
is: a split-only overwrite must replace the prior raw state, not silently keep it.

- [ ] **Step 3: Add an explicit materialization regression**

Add one case shaped like:

```asm
cmp     x0, x1
mrs     x2, nzcv
```

and assert the architectural bits still match the producer semantics after a raw
producer path.

- [ ] **Step 4: Build the focused regression**

Run:

```bash
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4
```

Expected:

- build succeeds

- [ ] **Step 5: Run the regression and confirm current main is missing at least one case**

Run:

```bash
./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- one or more new cases fail before the main-representation rework

- [ ] **Step 6: Commit the red test**

```bash
git add tests/tcg/aarch64/nzcv-status4.S
git commit -m "tests/aarch64: add deferred-flags main-representation regressions"
```

## Task 2: Introduce Durable `RAW/SPLIT` Representation State and TB Entry Tagging

**Files:**
- Modify: `target/arm/cpu.h`
- Modify: `target/arm/tcg/translate.c`
- Modify: `target/arm/tcg/hflags.c`
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: Define the durable representation contract in CPU state**

In `target/arm/cpu.h`, make the representation model explicit:

- durable `RAW` payload
- durable `SPLIT` payload
- representation tag used as current main state

Do not introduce a new large producer descriptor here.

- [ ] **Step 2: Expose any needed env globals in `translate.c`**

Export the env fields required by the translator so hot paths can directly emit
representation payload updates without ad hoc helper plumbing.

- [ ] **Step 3: Specialize A64 TBFLAGS on representation**

In `target/arm/tcg/hflags.c`, make the TB entry tag explicit:

- `ENTRY_FLAGS_RAW`
- `ENTRY_FLAGS_SPLIT`

Do not introduce a durable `LIVE_HOST` entry state.

- [ ] **Step 4: Initialize translator representation state from TBFLAGS**

In `target/arm/tcg/translate-a64.c`, remove the notion that hot consumers should
start in an indeterminate representation by default. The translator should begin
each TB with a concrete `RAW` or `SPLIT` state whenever possible.

- [ ] **Step 5: Verify the code still builds**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
```

Expected:

- build succeeds

- [ ] **Step 6: Commit the state-plumbing change**

```bash
git add target/arm/cpu.h target/arm/tcg/translate.c \
        target/arm/tcg/hflags.c target/arm/tcg/translate-a64.c
git commit -m "aarch64: add deferred flags main representation state"
```

## Task 3: Route Producers Into `RAW` or `SPLIT` Main State

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **Step 1: Make raw-friendly producers write durable `RAW` state directly**

Update the x86-friendly producer families so they treat `raw_flags + cc_op` as the
current flags main representation instead of a speculative sidecar:

- `CMP/SUBS`
- `CMN/ADDS`
- `ADCS/SBCS`
- `ANDS/BICS/TST`

- [ ] **Step 2: Make split-only producers overwrite into `SPLIT`**

For split-only producers such as:

- `CFINV`
- `XAFLAG`
- `AXFLAG`
- explicit `NZCV` writes

update `CF/VF/NF/ZF`, switch the representation tag to `SPLIT`, and stop treating
the previously cached raw payload as current architectural state.

- [ ] **Step 3: Remove implicit `RAW -> SPLIT` sync at TB exit**

Ensure TB exit preserves the final durable representation rather than always
forcing a split-state export.

- [ ] **Step 4: Re-run the architectural regression**

Run:

```bash
./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- the cross-TB and downgrade cases now pass

- [ ] **Step 5: Commit the producer routing**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: route flags producers into raw or split main state"
```

## Task 4: Rewire `B.cond` to Consume the Current Main Representation

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`
- Modify: `tests/tcg/aarch64/cmp-bcond-gap-host-direct.S`
- Modify: `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct`

- [ ] **Step 1: Keep the same-TB `LIVE_HOST` fast path for the hottest branch case**

Preserve the cheap same-TB host-flags branch lowering when the immediately
available host flags are still valid.

- [ ] **Step 2: Add a durable `RAW` branch-consumer path**

When `LIVE_HOST` is gone but the current main representation is `RAW`, lower
`B.cond` from `raw_flags + cc_op` directly instead of depending on `pending_cc`
pairing.

- [ ] **Step 3: Keep a direct `SPLIT` consumer path**

When the current main representation is `SPLIT`, lower `B.cond` directly from
`CF/VF/NF/ZF` without bouncing through canonical `NZCV`.

- [ ] **Step 4: Update the branch-focused harness if needed**

Adjust `cmp-bcond-gap-host-direct.S` and its checker so the positive oracle
still expects direct branch lowering, but no longer assumes success depends on
the old pairwise pending model.

- [ ] **Step 5: Build and run the focused checker**

Run:

```bash
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user cmp-bcond-gap-host-direct
bash tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
```

Expected:

- checker passes

- [ ] **Step 6: Commit the branch consumer rework**

```bash
git add target/arm/tcg/translate-a64.c \
        tests/tcg/aarch64/cmp-bcond-gap-host-direct.S \
        tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh
git commit -m "aarch64: consume deferred flags main state in b.cond"
```

## Task 5: Rewire `CSEL*` and `ADC/SBC` to Consume the Current Main Representation

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`
- Modify: `tests/tcg/aarch64/cmp-csel-gap-host-direct.S`
- Modify: `tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh`
- Modify: `tests/tcg/aarch64/adc-sbc-host-direct.S`
- Modify: `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`

- [ ] **Step 1: Add a durable `RAW` condition-consumer path for `CSEL*`**

Route `CSEL/CSINC/CSINV/CSNEG/CSET/CSETM` to derive their condition from the
current main representation:

- prefer `LIVE_HOST` when available
- otherwise read `RAW`
- otherwise read `SPLIT`

- [ ] **Step 2: Add a durable carry-consumer path for `ADC/SBC`**

Route plain `ADC/SBC` to read current guest carry from the main representation
instead of depending on pending compare pairing.

- [ ] **Step 3: Keep `ADCS/SBCS` as consume+overwrite**

Make sure `ADCS/SBCS`:

- consume current carry from `RAW` or `SPLIT`
- then overwrite the main representation with a new raw-friendly producer result

- [ ] **Step 4: Update focused codegen checkers**

Adjust:

- `check-cmp-csel-gap-host-direct.sh`
- `check-adc-sbc-host-direct.sh`

so they continue to require the hot direct path, but no longer encode the old
assumption that a positive case must come from a single pending producer record.

- [ ] **Step 5: Build and run both focused checkers**

Run:

```bash
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user \
  cmp-csel-gap-host-direct adc-sbc-host-direct
bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
bash tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

Expected:

- both checkers pass

- [ ] **Step 6: Commit the consumer rework**

```bash
git add target/arm/tcg/translate-a64.c \
        tests/tcg/aarch64/cmp-csel-gap-host-direct.S \
        tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
        tests/tcg/aarch64/adc-sbc-host-direct.S \
        tests/tcg/aarch64/check-adc-sbc-host-direct.sh
git commit -m "aarch64: consume deferred flags main state in csel and adc/sbc"
```

## Task 6: Shrink Runtime `UNKNOWN` Dispatch and Re-baseline the Hot Path

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- Test: focused codegen checkers

- [ ] **Step 1: Remove or isolate runtime representation dispatch from hot consumers**

Audit hot helpers that still emit runtime `RAW/SPLIT/UNKNOWN` branches and
replace them with:

- TB-entry specialization
- translation-time representation state updates

Leave runtime fallback only where architectural uncertainty truly cannot be
eliminated.

- [ ] **Step 2: Stop treating `pending_cc` as the main consumer contract**

Retain only the narrow, still-useful same-TB opportunistic pieces. The main
consumer contract must now be current representation state, not a long-lived
pending producer record.

- [ ] **Step 3: Re-run the core focused suite**

Run:

```bash
./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
bash tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
bash tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

Expected:

- all pass

- [ ] **Step 4: Commit the dispatch cleanup**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: specialize deferred flags representation in hot paths"
```

## Task 7: Run Closure, Update Progress, and Capture Initial Performance Direction

**Files:**
- Modify: `progress.md`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

- [ ] **Step 1: Run the focused local smoke suite**

Run:

```bash
./build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
./build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3
./build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench
```

Expected:

- all exit cleanly

- [ ] **Step 2: Re-run the three focused codegen checkers**

Run:

```bash
bash tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
bash tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

Expected:

- all pass

- [ ] **Step 3: Take one initial performance sanity read**

Use the smallest already-available local benchmark signal, not a full new report:

- `adcsbc-bench`
- one representative compare-heavy smoke case

The goal is only to make sure the rework did not obviously destroy the hot path.

- [ ] **Step 4: Update `progress.md`**

Record:

- `RAW/SPLIT` as main representations
- `LIVE_HOST` as same-TB opportunistic only
- current rollout boundary
- remaining open work (`CCMP/CCMN`, complex transforms, perf follow-up)

- [ ] **Step 5: Commit closure**

```bash
git add progress.md
git commit -m "docs: record deferred flags main-representation rollout"
```

## Notes for the Implementer

- Do not start by deleting `pending_cc`. First make `RAW/SPLIT` the main contract, then shrink `pending_cc` to the narrow opportunistic role that still makes sense.
- Do not introduce a new large durable producer descriptor. If the representation needs `lhs/rhs/carry_in/gap metadata` to remain valid, it is too heavy for this first main-representation rollout.
- Do not default to `RAW -> SPLIT` at TB exit. That loses the whole point of durable `RAW`.
- Do not reintroduce broad runtime `UNKNOWN` dispatch in hot consumers. If a path is hot, it should be specialized at TB entry or translator-state level.
- Do not pull full `CCMP/CCMN` generalization into the first pass unless the simpler `B.cond/CSEL*/ADC/SBC` rollout is already stable.
