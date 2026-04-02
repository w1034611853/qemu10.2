# Compare-like CSEL/CS* Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore compare-like `CSEL/CSINC/CSINV/CSNEG/CSET/CSETM` direct support without reintroducing the `531.deepsjeng_r test` correctness regression.

**Architecture:** Stop using the current compare-like `peek + keep alive` model for `CSEL/CS*`. Instead, let the consumer derive its condition from compare-like `pending_cc`, then immediately retire that producer into stable split flags so later flags users observe correct architectural NZCV without relying on long-lived compare-like pending state.

**Tech Stack:** QEMU TCG, AArch64 translator, x86 host backend, AArch64 assembly regressions, SPEC CPU2017 closure

---

## File Map

| File | Responsibility |
|------|------|
| `target/arm/tcg/translate-a64.c` | Implement compare-like `CSEL/CS*` retire-to-split path; replace current `peek + keep` model |
| `tests/tcg/aarch64/cmp-csel-gap-host-direct.S` | Update compare-like `CSEL/CS*` focused harness to match restored direct path |
| `tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh` | Re-enable positive direct-path oracle for compare-like `CSEL/CS*` |
| `tests/tcg/aarch64/nzcv-status4.S` | Add consumer-after-`CSEL/CS*` flags-visibility regressions |
| `progress.md` | Record the rework result and closure outcome |

## Task 1: Write Focused Failing Flags-After-Consumer Regressions

**Files:**
- Modify: `tests/tcg/aarch64/nzcv-status4.S`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **Step 1: Add one compare-like `CSEL` regression**

Add a case shaped like:

```asm
cmp     x0, x1
nop
csel    x2, x3, x4, eq
b.eq    ok
b       fail
```

The point is: `CSEL` may use the pending compare, but the later `b.eq` must still
see the original flags.

- [ ] **Step 2: Add one compare-like alias regression**

Add one alias-family case such as:

```asm
cmn     x0, x1
nop
cset    x2, cs
mrs     x3, nzcv
```

Check both:

- selected result is correct
- post-consumer NZCV still matches producer semantics

- [ ] **Step 3: Build the test**

Run:

```bash
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4
```

Expected:

- build succeeds

- [ ] **Step 4: Run the regression to verify current main still fails this new case**

Run:

```bash
./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- either `PASS` flips to failure
- or the new case forces a targeted failure once added

- [ ] **Step 5: Commit the red test**

```bash
git add tests/tcg/aarch64/nzcv-status4.S
git commit -m "tests/aarch64: add compare-like CSEL flags-after-consumer regression"
```

## Task 2: Implement Compare-like CSEL/CS* Retire-to-Split

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`
- Test: `tests/tcg/aarch64/nzcv-status4.S`

- [ ] **Step 1: Add a dedicated retire helper**

Create a helper in `translate-a64.c` that:

- accepts compare-like `pending_cc`
- recomputes producer NZCV bits from `lhs/rhs`
- writes split flags
- invalidates raw flags
- clears `pending_cc`

- [ ] **Step 2: Restrict the helper to compare-like producers only**

Guard the helper so it only accepts:

- `REWINDABLE_CMP`
- compare-like add/sub producer families

Do not reuse it for materialized add/carry producers.

- [ ] **Step 3: Change `trans_CSEL()` compare-like path**

For the `a64_try_peek_cmp_cond_bool_i32(..., "CSEL-pending")` branch:

- keep direct condition derivation
- stop leaving `pending_cc.keep = true` as the long-lived contract
- immediately retire compare-like producer to split flags after condition derivation

- [ ] **Step 4: Preserve current materialized add/carry branches**

Do not change:

- `CSEL-add-pending`
- `CSEL-carry-pending`

Those are outside this rework.

- [ ] **Step 5: Run the targeted regression**

Run:

```bash
./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- new flags-after-consumer cases pass

- [ ] **Step 6: Commit the implementation**

```bash
git add target/arm/tcg/translate-a64.c tests/tcg/aarch64/nzcv-status4.S
git commit -m "aarch64: retire compare-like CSEL into split flags"
```

## Task 3: Restore Focused compare-like CSEL/CS* Direct Checker

**Files:**
- Modify: `tests/tcg/aarch64/cmp-csel-gap-host-direct.S`
- Modify: `tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh`
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct`

- [ ] **Step 1: Reconfirm the intended positive cases**

Keep the existing positive shapes:

- `CSEL`
- `CSINC`
- `CSINV`
- `CSNEG`
- `CSET`
- `CSETM`

with compare-like producers only.

- [ ] **Step 2: Make the checker expect direct compare-like `CSEL-pending` again**

Restore positive assertions for:

- `record`
- `peek`
- `via=CSEL-pending`

for the compare-like cases.

- [ ] **Step 3: Keep the bad-gap negative case**

Retain the current “bad gap” negative oracle.

- [ ] **Step 4: Rebuild the harness**

Run:

```bash
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user cmp-csel-gap-host-direct
```

Expected:

- build succeeds

- [ ] **Step 5: Run the checker**

Run:

```bash
bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
```

Expected:

- checker passes

- [ ] **Step 6: Commit the restored checker**

```bash
git add tests/tcg/aarch64/cmp-csel-gap-host-direct.S \
        tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh
git commit -m "tests/aarch64: restore compare-like CSEL direct oracle"
```

## Task 4: Run Closure

**Files:**
- Modify: `progress.md`
- Test: local smoke + SPEC closure

- [ ] **Step 1: Run local smoke**

Run:

```bash
./build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench
./build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3
./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- all exit cleanly

- [ ] **Step 2: Run focused non-branch checkers**

Run:

```bash
bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
bash tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-ccmp-gap-host-direct
bash tests/tcg/aarch64/check-cmp-fcsel-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-fcsel-gap-host-direct
bash tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh \
  ./build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-fccmp-gap-host-direct
```

Expected:

- all pass

- [ ] **Step 3: Run SPEC 7 benchmark test-size closure**

Run:

```bash
cd /home/wangruoyu/cpuspec2017
./bin/runcpu \
  --config /home/wangruoyu/cpuspec2017/config/qemu_aarch64_tcg.cfg \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  500.perlbench_r 502.gcc_r 505.mcf_r 523.xalancbmk_r \
  531.deepsjeng_r 541.leela_r 557.xz_r
```

Expected:

- `531.deepsjeng_r` removed from the `Error:` line
- only `500.perlbench_r` may remain, with the known nested-perl signature

- [ ] **Step 4: Update progress**

Add to `progress.md`:

- compare-like `CSEL/CS*` restored
- implementation now uses retire-to-split model
- `531` closure evidence

- [ ] **Step 5: Commit closure docs**

```bash
git add progress.md
git commit -m "docs: record compare-like CSEL rework closure"
```
