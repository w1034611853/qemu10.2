# Progress

This is the canonical progress tracker for the AArch64-on-x86 TCG direct-path
work in this repo.

From this point on, new progress updates should land here first. Older handoff,
matrix, and plan files remain useful as historical references, but this file is
the main running summary.

Archive-only historical notes now live under `docs/superpowers/archive/`:

- `docs/superpowers/archive/codex_a64_x86_status4_handoff.md`
- `docs/superpowers/archive/handoff.md`
- `docs/superpowers/archive/2026-04-01-direct-path-candidate-matrix.md`
- `docs/superpowers/archive/2026-03-31-adcs-sbcs-direct-consumer-fix-plan.md`
- `docs/superpowers/archive/2026-03-31-adcs-sbcs-direct-consumer-implementation.md`
- `docs/superpowers/archive/2026-04-01-adcs-sbcs-producer-direct-consumer.md`
- `docs/superpowers/archive/2026-04-01-lazy-compare-phase-2-bcond.md`

## Scope

Project focus:

- AArch64 guest on x86 host
- TCG direct-path / lazy-compare optimization
- Reuse x86 host flags where possible instead of eagerly materializing guest
  NZCV state

## Repo State

Main workspace:

- repo: `/home/wangruoyu/qemu10.2`
- branch: `a64-x86-status4-v10.2.0`
- current main `HEAD`:
  `65b9375654` (`docs: update progress after CSEL rework merge`)

Main branch now includes:

- the earlier `adcs-sbcs-producer-direct-v10.2.0` merge
- the compare-like `CSEL/CS*` rework merge

Latest merged fix commit under that merge:

- `47d27a1bb1` `aarch64: rework compare-like CSEL pending retirement`

Active isolated worktree:

- path:
  `/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct`
- branch:
  `adcs-sbcs-producer-direct-v10.2.0`
- current worktree `HEAD`:
  `5f350f8f0c` (`aarch64: chain ADCS/SBCS rd into gap floating consumers`)

Repo-local debug worktree cleanup:

- obsolete repo-local `531-*`, `regression-debug`, and
  `compare-like-csel-cs-baseline` worktrees have been removed
- the remaining repo-local feature worktree is:
  `adcs-sbcs-producer-direct-v10.2.0`

## What Is Complete

### 1. `ADCS/SBCS` direct-consumer line

This line is functionally complete and still green.

Supported direct paths include:

- `CMN / ADDS xzr,... -> ADC`
- `CMP / SUBS xzr,... -> SBC`
- `ADDS rd,... -> ADC`
- `SUBS rd,... -> SBC`
- `ADDS rd,... -> ADCS`
- `SUBS rd,... -> SBCS`
- `ADCS/SBCS -> ADC/SBC`
- `ADCS/SBCS -> ADCS/SBCS`

Deliberate exclusions that still fall back:

- `CMN -> ADCS`
- `CMP -> SBCS`

Reason:

- compare-like `CMN/CMP` producers are `REWINDABLE_CMP`
- their carry/borrow is not a materialized live host `CF`

### 2. `lazy compare phase 2 B.cond` first rollout

The `B.cond` line is no longer just compare-like `CMP`.

Current worktree support now includes:

- bounded-gap `CMP/SUBS xzr -> B.cond`
- bounded-gap `CMN/ADDS xzr -> B.cond`
- bounded-gap `ADCS xzr -> B.cond`
- bounded-gap `ADCS rd -> B.cond`
- bounded-gap `SBCS rd -> B.cond`

Current condition coverage on the add side includes:

- `EQ/NE/CS/CC/HI/LS/GE/LT/GT/LE`
- `MI/PL/VS/VC`

Current materialized carry-producer scope:

- `ADCS/SBCS rd -> B.cond` is intentionally limited to non-adjacent gap cases
- adjacent materialized carry-producer branch users still keep the preexisting
  behavior

Current invalidation model:

- non-whitelist gap instruction: no use
- flags writer in the gap: no use
- gap overflow (`> 8`): no use
- page boundary / TB-style cut: producer may decline to record
- direct control-flow cut: producer may decline to record

Important adjacency note:

- adjacent precedence is currently validated as stable direct `age=1` consume
- exact `rewind` trace parity is still deferred
- attempts to restore old rewind bookkeeping reopened:
  - `temp_load: code should not be reached`

### 3. Compare-like non-branch status on main branch

Compare-like non-branch support is now restored on main branch, including the
previously disabled `CSEL/CS*` family:

- compare-like `CSEL/CSINC/CSINV/CSNEG/CSET/CSETM`: enabled
- compare-like `CCMP/CCMN`: enabled
- compare-like `FCSEL`: enabled
- compare-like `FCCMP`: enabled

Current `CSEL/CS*` model is no longer the old `peek + keep alive` path.
Instead:

- compare-like producer conditions are consumed locally in `trans_CSEL()`
- the condition result is derived from producer NZCV bits
- producer flags are immediately retired into split flags

This is the model introduced by:

- `47d27a1bb1` `aarch64: rework compare-like CSEL pending retirement`

Reason this replaced the older model:

- SPEC `531.deepsjeng_r test` exposed a real correctness hole in the previous
  compare-like `CSEL/CS*` pending-peek lifetime
- the rework preserves direct-path behavior while restoring correct flags
  lifetime after the consumer

## Latest Worktree Commits

Latest main-branch merge and fix:

- `2fb8ccb1c4` `Merge branch 'compare-like-csel-cs-rework-v10.2.0' into a64-x86-status4-v10.2.0`
- `47d27a1bb1` `aarch64: rework compare-like CSEL pending retirement`

Recent branch tip history:

- `5f350f8f0c` `aarch64: chain ADCS/SBCS rd into gap floating consumers`
- `59bd0636f0` `aarch64: chain ADCS/SBCS rd into gap CCMP`
- `ae79dbc977` `aarch64: chain ADCS/SBCS rd into gap CSEL`
- `e3d336d0b1` `tests/aarch64: strengthen logic producer host-block assertions`
- `80acb12aae` `aarch64: narrow add-like lazy B.cond conditions`
- `5f09260d2e` `aarch64: chain ADDS/SUBS rd into gap floating consumers`
- `ac64c57b45` `aarch64: chain ADDS/SUBS rd into gap CCMP`
- `14703516aa` `aarch64: chain ADDS rd into gap CSEL aliases`
- `d457c0747a` `aarch64: chain SUBS rd into gap CSEL aliases`
- `ce02b8a86b` `tests/aarch64: tighten logic gap csel-ccmp checker`
- `07d15b8955` `tests/aarch64: cover logic gap CSEL and CCMP`
- `fbfe69876b` `aarch64: chain compare-like producers into gap FCCMP`
- `1c8afa5fe9` `aarch64: chain compare-like producers into gap FCSEL`
- `c709c5930f` `aarch64: chain compare-like producers into gap CCMP`
- `0a11c85477` `tests/aarch64: cover gap CSEL aliases`
- `7ec1f2a038` `aarch64: chain compare-like producers into gap CSEL`
- `6a34900692` `tests/aarch64: cover 32-bit carry B.cond gaps`
- `996e400881` `aarch64: chain SBCS rd into lazy B.cond`
- `c23d399354` `aarch64: chain ADCS rd into lazy B.cond`
- `05838b8e0a` `aarch64: chain ADCS xzr into lazy B.cond`
- `eece17cd54` `aarch64: extend add-like lazy B.cond jcc coverage`
- `6653c87c86` `aarch64: extend lazy compare B.cond add-side coverage`
- `491e051771` `aarch64: make lazy compare B.cond lifetime explicit`
- `2464ce86a0` `tests/aarch64: tighten lazy compare gap invalidation coverage`
- `29f21e7534` `tests/aarch64: add lazy compare B.cond gap harness`

## Fresh Verification Evidence

These focused checks are currently green on the merged main branch:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
./build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3
./build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench
bash tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build-aarch64-linux-user/qemu-aarch64 \
    build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
cd /home/wangruoyu/cpuspec2017/benchspec/CPU/531.deepsjeng_r/run/run_base_test_mytest-64.0000
/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu \
    ./deepsjeng_r_base.mytest-64 test.txt > 531-main.out 2>531-main.err
/home/wangruoyu/cpuspec2017/bin/specperl \
    /home/wangruoyu/cpuspec2017/bin/harness/specdiff -m -l 10 --obiwan \
    /home/wangruoyu/cpuspec2017/benchspec/CPU/531.deepsjeng_r/data/test/output/test.out \
    531-main.out > 531-main.cmp
```

Observed result:

- `check-cmp-csel-gap-host-direct.sh`: PASS
- `nzcv-status4`: `PASS`
- `cmpstress-o3`: exit code `0`
- `adcsbc-bench`: exit code `0`
- `check-adc-sbc-host-direct.sh`: PASS
- `531.deepsjeng_r test`: `RUN_RC=0`, `DIFF_RC=0`

## External Functional Correctness Results

Additional functional-correctness coverage is recorded in:

- `/home/wangruoyu/qemu_nzcv/functional_test_results.md`

That result set records:

- CoreMark: PASS
- Dhrystone: PASS
- SPEC CPU2017 `test` size:
  - `502.gcc_r`: PASS
  - `505.mcf_r`: PASS
  - `520.omnetpp_r`: PASS
  - `523.xalancbmk_r`: PASS
  - `525.x264_r`: PASS, with separate image validation showing
    `AVG SSIM: 1.000000000`
  - `531.deepsjeng_r`: PASS
  - `541.leela_r`: PASS
  - `557.xz_r`: PASS

Known exception:

- `500.perlbench_r` remains excluded from that summary because it still needs
  the nested-perl wrapper workaround documented in
  `docs/superpowers/summaries/2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md`

Practical reading of the current correctness state:

- local focused TCG regressions are green on main
- direct `531.deepsjeng_r test` `specdiff` is green on main
- the external benchmark summary covers a wider user-visible workload set
- the remaining correctness caveat is still `500.perlbench_r` harness handling,
  not a demonstrated NZCV semantic regression

Historical worktree-era focused checks that were green during the larger
feature expansion remain listed below for reference:

```bash
bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct
bash tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-ccmp-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/cmp-ccmp-gap-host-direct
bash tests/tcg/aarch64/check-cmp-fcsel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-fcsel-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/cmp-fcsel-gap-host-direct
bash tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-fccmp-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/cmp-fccmp-gap-host-direct
bash tests/tcg/aarch64/check-logic-csel-ccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/logic-csel-ccmp-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/logic-csel-ccmp-gap-host-direct
bash tests/tcg/aarch64/check-subs-rd-csel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/subs-rd-csel-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/subs-rd-csel-gap-host-direct
bash tests/tcg/aarch64/check-adds-rd-csel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adds-rd-csel-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/adds-rd-csel-gap-host-direct
bash tests/tcg/aarch64/check-subs-rd-ccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/subs-rd-ccmp-gap-host-direct
bash tests/tcg/aarch64/check-adds-rd-ccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adds-rd-ccmp-gap-host-direct
bash tests/tcg/aarch64/check-subs-rd-fcsel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/subs-rd-fcsel-gap-host-direct
bash tests/tcg/aarch64/check-adds-rd-fcsel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adds-rd-fcsel-gap-host-direct
bash tests/tcg/aarch64/check-subs-rd-fccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/subs-rd-fccmp-gap-host-direct
bash tests/tcg/aarch64/check-adds-rd-fccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adds-rd-fccmp-gap-host-direct
bash tests/tcg/aarch64/check-adcs-rd-csel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adcs-rd-csel-gap-host-direct
bash tests/tcg/aarch64/check-sbcs-rd-csel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/sbcs-rd-csel-gap-host-direct
bash tests/tcg/aarch64/check-adcs-rd-ccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adcs-rd-ccmp-gap-host-direct
bash tests/tcg/aarch64/check-sbcs-rd-ccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/sbcs-rd-ccmp-gap-host-direct
bash tests/tcg/aarch64/check-adcs-rd-fcsel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adcs-rd-fcsel-gap-host-direct
bash tests/tcg/aarch64/check-sbcs-rd-fcsel-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/sbcs-rd-fcsel-gap-host-direct
bash tests/tcg/aarch64/check-adcs-rd-fccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adcs-rd-fccmp-gap-host-direct
bash tests/tcg/aarch64/check-sbcs-rd-fccmp-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/sbcs-rd-fccmp-gap-host-direct
```

Observed result:

- `check-cmp-bcond-gap-host-direct.sh`: PASS
- `cmp-bcond-gap-host-direct`: exit code `0`
- `check-cmp-bcond-ext-host-direct.sh`: PASS
- `check-adc-sbc-host-direct.sh`: PASS
- `adc-sbc-host-direct`: exit code `0`
- `nzcv-status4`: `PASS`
- `check-cmp-csel-gap-host-direct.sh`: PASS
- `cmp-csel-gap-host-direct`: exit code `0`
- `check-cmp-ccmp-gap-host-direct.sh`: PASS
- `cmp-ccmp-gap-host-direct`: exit code `0`
- `check-cmp-fcsel-gap-host-direct.sh`: PASS
- `cmp-fcsel-gap-host-direct`: exit code `0`
- `check-cmp-fccmp-gap-host-direct.sh`: PASS
- `cmp-fccmp-gap-host-direct`: exit code `0`
- `check-logic-csel-ccmp-gap-host-direct.sh`: PASS
- `logic-csel-ccmp-gap-host-direct`: exit code `0`
- `check-subs-rd-csel-gap-host-direct.sh`: PASS
- `subs-rd-csel-gap-host-direct`: exit code `0`
- `check-adds-rd-csel-gap-host-direct.sh`: PASS
- `adds-rd-csel-gap-host-direct`: exit code `0`
- `check-subs-rd-ccmp-gap-host-direct.sh`: PASS
- `check-adds-rd-ccmp-gap-host-direct.sh`: PASS
- `check-subs-rd-fcsel-gap-host-direct.sh`: PASS
- `check-adds-rd-fcsel-gap-host-direct.sh`: PASS
- `check-subs-rd-fccmp-gap-host-direct.sh`: PASS
- `check-adds-rd-fccmp-gap-host-direct.sh`: PASS
- `check-adcs-rd-csel-gap-host-direct.sh`: PASS
- `check-sbcs-rd-csel-gap-host-direct.sh`: PASS
- `check-adcs-rd-ccmp-gap-host-direct.sh`: PASS
- `check-sbcs-rd-ccmp-gap-host-direct.sh`: PASS
- `check-adcs-rd-fcsel-gap-host-direct.sh`: PASS
- `check-sbcs-rd-fcsel-gap-host-direct.sh`: PASS
- `check-adcs-rd-fccmp-gap-host-direct.sh`: PASS
- `check-sbcs-rd-fccmp-gap-host-direct.sh`: PASS

## Why We Are Not Continuing `B.cond` First

`B.cond` is not "done forever", but it is no longer the best immediate ROI.

Reasons:

- the branch line is already broad:
  - compare-like producers
  - add-side producers
  - carry producers
  - materialized carry producers
- the remaining branch work is increasingly about:
  - smaller coverage fill-in
  - adjacency scope decisions
  - trace-parity cleanup
  - not the next big unlock
- the architectural next win is to reuse the bounded pending-compare lifetime
  for non-branch consumers

Still possible on the branch line if we need to come back:

- materialized carry-producer adjacency policy changes
- exact adjacent `rewind` bookkeeping parity
- any leftover 32-bit or condition-coverage cleanup

## Next Direction

Next coding focus:

- materialized setflags producers into the already-landed non-branch consumers

Recommended next slice:

- decide whether to stop producer expansion here or continue into carry
  producers / logic producers

Why this is next:

- the compare-like non-branch family is now broad and green
- `SUBS rd -> CSEL/CS*` and `ADDS rd -> CSEL/CS*` are both landed, so the
  materialized setflags producer pattern is now proven on the same
  [`trans_CSEL()`](/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct/target/arm/tcg/translate-a64.c#L12794) consumer path
- `CCMP/CCMN` is now also covered by materialized `ADDS/SUBS rd`, so the next
  nearby decision is no longer “what’s the next missing consumer in this
  family”, because the floating conditional consumers are now covered too

Likely follow-ons from here:

- materialized carry producers into non-branch consumers
- stronger codegen/path-shape assertions for logic producers
- or pause feature expansion and consolidate docs / perf / merge strategy

## Closure Update

The `step 3` closure pass found an important blocker:

- focused feature tests are green on worktree tip `5f09260d2e`
- but the broader smoke/perf binaries:
  - `adcsbc-bench`
  - `cmpstress-o3`
  crash with `SIGSEGV` on the worktree tip
- the same binaries run successfully on the main workspace branch
  `ffcf55b840`

This means the worktree-only materialized non-branch producer stack is **not
merge-ready yet**.

Current consequence:

- do not merge/cherry-pick the four worktree-only feature commits yet
- debug the crash before moving on to more expansion work

Further debugging narrowed the first bad commit to:

- `6653c87c86` `aarch64: extend lazy compare B.cond add-side coverage`

So the current blocker predates the later materialized non-branch producer
stack. The most likely crash source is in the add-side lazy `B.cond` rollout,
not in the later `CSEL/CCMP/FCSEL/FCCMP` materialized-producer commits
themselves.

That blocker is now addressed on the feature worktree by:

- `80acb12aae` `aarch64: narrow add-like lazy B.cond conditions`

This fix narrows add/adc-like lazy `B.cond` direct support to the safe subset:

- `EQ/NE`
- `MI/PL`
- `VS/VC`
- `GE/LT/GT/LE`

and drops the unsafe carry/unsigned subset from the add-side direct path:

- `CS/CC/HI/LS`

Post-fix closure evidence:

- `adcsbc-bench`: `RC=0`
- `cmpstress-o3`: `RC=0`
- `check-cmp-bcond-gap-host-direct.sh`: PASS
- `check-cmp-bcond-ext-host-direct.sh`: PASS
- `check-adc-sbc-host-direct.sh`: PASS
- `nzcv-status4`: PASS

On the merged main branch, the add/adc unsigned branch subset was later
re-enabled with dedicated lowering rather than the old compare-style mapping:

- `CS/CC` now use add/adc-specific carry JCC lowering
- `HI` now uses a zero-clear guard plus carry-set branch shape
- `LS` now uses a zero-set or carry-clear branch shape

This restores:

- `CMN/ADDS xzr -> B.cond` for `CS/CC/HI/LS`
- `ADCS xzr -> B.cond` for `CS/CC/HI/LS`
- `ADCS rd -> B.cond` for `CS/CC/HI/LS`

Fresh evidence after that restoration:

- `check-cmp-bcond-gap-host-direct.sh`: PASS
- `cmp-bcond-gap-host-direct`: exit code `0`
- `adcsbc-bench`: `RC=0`
- `cmpstress-o3`: `RC=0`
- `nzcv-status4`: `PASS`
- `check-adc-sbc-host-direct.sh`: PASS
- `check-cmp-bcond-ext-host-direct.sh`: PASS

## First Non-Branch Slice

On `2026-04-02`, the first non-branch slice landed in the active worktree:

- bounded-gap `compare-like producer -> CSEL`
- commit:
  - `7ec1f2a038` `aarch64: chain compare-like producers into gap CSEL`
  - `0a11c85477` `tests/aarch64: cover gap CSEL aliases`

What this slice does:

- adds future-`CSEL` gap lookahead for compare-like producers
- keeps the existing `B.cond` line untouched
- avoids changing global condition-consumer priority
- gives `trans_CSEL()` its own pending-compare "peek" path

Most important design lesson:

- non-branch consumers should not reuse the `B.cond` consume model directly
- `CSEL` is more stable with a non-terminal peek model:
  - use pending compare to derive the condition
  - keep the pending compare alive for later consumers

Current next step after this slice:

- extend the same non-terminal pattern across:
  - `CSINC/CSINV/CSNEG/CSET/CSETM`
- then move to:
  - bounded-gap `CCMP/CCMN`

## Second Non-Branch Slice

The next non-branch slice is now also landed in the active worktree:

- bounded-gap `compare-like producer -> CCMP/CCMN`
- commit:
  - `c709c5930f` `aarch64: chain compare-like producers into gap CCMP`

What this slice does:

- adds future-`CCMP/CCMN` gap lookahead for compare-like producers
- reuses the existing `trans_CCMP()` consumer logic
- does not require the `CSEL`-style non-terminal peek model, because `CCMP/CCMN`
  are terminal flag-producing consumers

Most important design lesson:

- `CCMP/CCMN` was simpler than `CSEL`
- producer-side bounded-gap record was the main missing piece
- the existing consumer path was already structurally compatible

Current next step after this slice:

- move from integer non-branch consumers to floating conditional consumers:
  - `FCSEL`
  - then `FCCMP`
- or branch sideways into:
  - `ANDS/TST -> CSEL/CCMP`

## Third Non-Branch Slice

The next nearby floating conditional-select slice is now landed too:

- bounded-gap `compare-like producer -> FCSEL`
- commit:
  - `1c8afa5fe9` `aarch64: chain compare-like producers into gap FCSEL`

What this slice does:

- adds future-`FCSEL` gap lookahead for compare-like producers
- gives `trans_FCSEL()` the same local pending-compare peek pattern used by
  `trans_CSEL()`
- keeps the branch and arithmetic direct-path work untouched

Most important design lesson:

- `FCSEL` maps cleanly onto the same non-terminal peek model as `CSEL`
- the consumer-local approach continues to be safer than any global
  condition-priority rewrite

Current next step after this slice:

- `FCCMP`

## Fourth Non-Branch Slice

The next floating conditional-compare slice is now landed too:

- bounded-gap `compare-like producer -> FCCMP`
- commit:
  - `fbfe69876b` `aarch64: chain compare-like producers into gap FCCMP`

What this slice does:

- adds future-`FCCMP` gap lookahead for compare-like producers
- updates `trans_FCCMP()` to decide its condition through the same
  pending-compare-aware bool path used elsewhere
- keeps existing `B.cond`, arithmetic, `CSEL`, `CCMP`, and `FCSEL` work green

Most important design lesson:

- `FCCMP` sits closer to `CCMP` than to `FCSEL` in overall structure
- but condition selection still needed explicit pending-compare-aware handling,
  not just producer lookahead

Current next step after this slice:

- evaluate whether to keep pushing deeper into floating conditional consumers,
  or pivot back to:
  - `ANDS/TST -> CSEL/CCMP`

## Logic Producer Coverage

The first `ANDS/TST -> CSEL/CCMP` step turned out to be a coverage slice:

- commit:
  - `07d15b8955` `tests/aarch64: cover logic gap CSEL and CCMP`

What this means:

- current logical RAW-flags producer handling already supports the tested
  bounded-gap `CSEL` / `CCMP` semantics
- no translator change was required for this first logic slice

Current implication:

- if we continue down the logic route, the next likely value is stronger
  codegen/path-shape validation rather than basic semantic enablement

## Materialized `SUBS rd -> CSEL/CS*`

On `2026-04-02`, the first materialized setflags producer slice for non-branch
consumers landed in the active worktree:

- bounded-gap `SUBS rd -> CSEL/CSINC/CSINV/CSNEG/CSET/CSETM`
- commit:
  - `d457c0747a` `aarch64: chain SUBS rd into gap CSEL aliases`

What this slice does:

- adds future-`CSEL` gap recording for materialized `SUBS rd` producers in the
  register form
- reuses the existing consumer-local `CSEL-pending` peek path rather than
  changing global condition priority
- keeps the `SUBS rd` result write intact while also preserving pending compare
  state for the later consumer

Why this shape was chosen:

- it is the lowest-risk producer-side extension after the compare-like family
- `SUBS` condition semantics already line up with compare-style condition
  evaluation for the `CSEL/CS*` family we currently support
- it avoids mixing in add-side condition semantics before the sub-side path is
  proven

Fresh evidence for this slice:

- `check-subs-rd-csel-gap-host-direct.sh`: PASS
- `subs-rd-csel-gap-host-direct`: exit code `0`
- `nzcv-status4`: `PASS`
- existing `cmp-csel`, `adc-sbc`, and logic-gap focused checks remain green

## Materialized `ADDS rd -> CSEL/CS*`

Also on `2026-04-02`, the add-side counterpart landed in the active worktree:

- bounded-gap `ADDS rd -> CSEL/CSINC/CSINV/CSNEG/CSET/CSETM`
- commit:
  - `14703516aa` `aarch64: chain ADDS rd into gap CSEL aliases`

What this slice does:

- adds future-`CSEL` gap recording for materialized `ADDS rd` producers in the
  register form
- introduces an add-specific pending-condition bool path, instead of reusing
  compare-style `lhs/rhs` evaluation
- gives [`trans_CSEL()`](/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct/target/arm/tcg/translate-a64.c#L12794) a consumer-local
  `CSEL-add-pending` path for add-only conditions such as `VS/VC`

Why this shape was needed:

- unlike `SUBS`, add-side conditions are not safely expressible as plain
  `lhs ? rhs` compare relations
- a compare-style pending peek would silently compute the wrong answer for
  add-only conditions
- the producer-side gap lifetime still stays shared; only the bool derivation
  is specialized

Fresh evidence for this slice:

- `check-adds-rd-csel-gap-host-direct.sh`: PASS
- `adds-rd-csel-gap-host-direct`: exit code `0`
- `check-subs-rd-csel-gap-host-direct.sh`: PASS
- `check-cmp-csel-gap-host-direct.sh`: PASS
- `check-logic-csel-ccmp-gap-host-direct.sh`: PASS
- `check-adc-sbc-host-direct.sh`: PASS
- `nzcv-status4`: `PASS`

## Materialized `ADDS/SUBS rd -> CCMP/CCMN`

Still on `2026-04-02`, the next non-branch materialized producer slice landed:

- bounded-gap `SUBS rd -> CCMP/CCMN`
- bounded-gap `ADDS rd -> CCMP/CCMN`
- commit:
  - `ac64c57b45` `aarch64: chain ADDS/SUBS rd into gap CCMP`

What this slice does:

- adds future-`CCMP` gap recording for materialized `SUBS rd` and `ADDS rd`
  producers in the register form
- reuses the existing [`trans_CCMP()`](/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct/target/arm/tcg/translate-a64.c#L12934) consumer logic
  rather than introducing a new consumer-local path
- relies on the now-shared `a64_test_cc_bool_i32()` entry, which already knows
  how to derive conditions from both materialized sub-side and add-side
  pending producers

Why this slice was cheaper than `CSEL`:

- `CCMP/CCMN` was already structurally aligned around `a64_test_cc_bool_i32()`
- once the add/sub materialized bool paths existed for `CSEL`, the missing
  piece here was mainly producer-side future-gap recording
- no new `CCMP`-specific bool helper was needed

Fresh evidence for this slice:

- `check-subs-rd-ccmp-gap-host-direct.sh`: PASS
- `check-adds-rd-ccmp-gap-host-direct.sh`: PASS
- `check-cmp-ccmp-gap-host-direct.sh`: PASS
- `check-cmp-csel-gap-host-direct.sh`: PASS
- `check-adc-sbc-host-direct.sh`: PASS
- `nzcv-status4`: `PASS`

## Materialized `ADDS/SUBS rd -> FCSEL/FCCMP`

The next floating conditional-consumer slice also landed on `2026-04-02`:

- bounded-gap `SUBS rd -> FCSEL`
- bounded-gap `ADDS rd -> FCSEL`
- bounded-gap `SUBS rd -> FCCMP`
- bounded-gap `ADDS rd -> FCCMP`
- commit:
  - `5f09260d2e` `aarch64: chain ADDS/SUBS rd into gap floating consumers`

What this slice does:

- adds future-`FCSEL` / future-`FCCMP` gap recording for materialized
  `ADDS/SUBS rd` producers in the register form
- extends [`trans_FCSEL()`](/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct/target/arm/tcg/translate-a64.c#L10844) with an add-side
  pending peek, mirroring the integer `CSEL` work
- keeps [`trans_FCCMP()`](/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct/target/arm/tcg/translate-a64.c#L11203) on the shared
  `a64_test_cc_bool_i32()` path, with terminal-consumer tracing normalized to
  `via=FCCMP`

Why this completed the family cleanly:

- `FCSEL` needed the same split as `CSEL`:
  - materialized `SUBS` can reuse compare-style pending bool
  - materialized `ADDS` needs add-specific pending bool
- `FCCMP` stayed closer to `CCMP`:
  - producer-side future-gap record was the missing piece
  - the shared bool path already handled both materialized add/sub producers

Fresh evidence for this slice:

- `check-subs-rd-fcsel-gap-host-direct.sh`: PASS
- `check-adds-rd-fcsel-gap-host-direct.sh`: PASS
- `check-subs-rd-fccmp-gap-host-direct.sh`: PASS
- `check-adds-rd-fccmp-gap-host-direct.sh`: PASS
- `check-cmp-fcsel-gap-host-direct.sh`: PASS
- `check-cmp-fccmp-gap-host-direct.sh`: PASS
- `check-cmp-csel-gap-host-direct.sh`: PASS
- `check-cmp-ccmp-gap-host-direct.sh`: PASS
- `check-adc-sbc-host-direct.sh`: PASS
- `nzcv-status4`: `PASS`

## Materialized `ADCS/SBCS rd -> CSEL/CCMP/FCSEL/FCCMP`

The next carry-producer non-branch slices landed on `2026-04-02`:

- bounded-gap `ADCS rd -> CSEL`
- bounded-gap `SBCS rd -> CSEL`
- bounded-gap `ADCS rd -> CCMP`
- bounded-gap `SBCS rd -> CCMP`
- bounded-gap `ADCS rd -> FCSEL`
- bounded-gap `SBCS rd -> FCSEL`
- bounded-gap `ADCS rd -> FCCMP`
- bounded-gap `SBCS rd -> FCCMP`

Commits:

- `ae79dbc977` `aarch64: chain ADCS/SBCS rd into gap CSEL`
- `59bd0636f0` `aarch64: chain ADCS/SBCS rd into gap CCMP`
- `5f350f8f0c` `aarch64: chain ADCS/SBCS rd into gap floating consumers`

What these slices do:

- extend the bounded-gap non-branch family from materialized plain add/sub
  producers to materialized carry-producing `ADCS/SBCS rd`
- keep `CSEL` / `FCSEL` on consumer-local carry-aware peek paths
- reuse the shared bool path for terminal `CCMP` / `FCCMP`
- preserve the broader smoke/perf closure after the add-like branch fix

Fresh evidence for this slice:

- `check-adcs-rd-csel-gap-host-direct.sh`: PASS
- `check-sbcs-rd-csel-gap-host-direct.sh`: PASS
- `check-adcs-rd-ccmp-gap-host-direct.sh`: PASS
- `check-sbcs-rd-ccmp-gap-host-direct.sh`: PASS
- `check-adcs-rd-fcsel-gap-host-direct.sh`: PASS
- `check-sbcs-rd-fcsel-gap-host-direct.sh`: PASS
- `check-adcs-rd-fccmp-gap-host-direct.sh`: PASS
- `check-sbcs-rd-fccmp-gap-host-direct.sh`: PASS
- `adcsbc-bench`: `RC=0`
- `cmpstress-o3`: `RC=0`
- `nzcv-status4`: `PASS`

## Adjacent `ANDS/TST -> CCMP/CCMN` Host-JCC Direct Path

On `2026-04-07`, the next logic-producer optimization slice landed in the
working tree:

- adjacent `ANDS/TST -> CCMP`
- adjacent `ANDS/TST -> CCMN`

What this slice does:

- adds an x86-host-flags condition fast path for adjacent logic producers in
  [`trans_CCMP()`](/home/ruoyu/code/qemu_nzcv/qemu10.2/target/arm/tcg/translate-a64.c)
- uses `x86_jcc` on the live host flags from the preceding `ANDS/TST` to pick
  between:
  - the literal fallback NZCV
  - the computed `CCMP/CCMN` add/sub NZCV
- keeps the result in canonical raw NZCV form, so downstream consumers still
  see the usual raw-flags state
- removes the old adjacent logic path's `a64_test_cc_bool_i32()` /
  `movcond_i32` raw-flags condition decode from this consumer

What this slice does not try to do:

- it does not keep `CCMP/CCMN` results as a new live-host-flags producer
- it is a consumer-side fast path, not a new compare-like producer model

Fresh evidence for this slice:

- `check-logic-ccmp-host-direct.sh`: PASS
- `logic-ccmp-host-direct`: exit code `0`
- `check-logic-csel-host-direct.sh`: PASS
- `check-logic-csel-ccmp-gap-host-direct.sh`: PASS

## Logic `CSEL/CS*` Dirty-Tree Correctness Fix

On `2026-04-07`, a local dirty-worktree regression in the adjacent
`ANDS/TST -> CSEL/CS*` fast path was traced to one specific host-codegen
pattern:

- materializing a logical consumer-side constant `0` with plain `movi`
- on x86 this became `xor reg, reg`
- that `xor` clobbered the live host flags that the following `x86_cmov`
  was supposed to consume

This showed up in two places:

- `CSET/CSETM`, where the false path starts from `0`
- `CSEL/CS*` forms that read `ZR`, where `read_cpu_reg(..., 31, ...)`
  also built the source with `movi 0`

What changed:

- added a host-only `x86_movi_noflags` TCG op that forces a mov-style
  constant materialization instead of the flag-clobbering zeroing idiom
- switched the adjacent logic `CSEL/CS*` fast path to use that op for:
  - `CSET/CSETM` false-path `0`
  - `CSET/CSETM` true-path `1/-1`
  - any `rn == zr` / `rm == zr` source inside the direct path
- kept the earlier `rd == rn` overlap fix in place so the true-path source is
  snapped before writing the false path into `rd`

Focused coverage added for the blind spots that caused the regression:

- `CSET` false case
- `CSETM` false case
- `CSEL ... , xzr` false case
- `CSEL xzr, ...` false case

Fresh evidence for this fix:

- `/tmp/cset-like-sanity`: `RC=0`
- `/tmp/csel-zr-sanity`: `RC=0`
- `check-logic-csel-host-direct.sh`: PASS
- `logic-csel-host-direct`: `RC=0`
- quick SPEC dirty-tree repros:
  - `502.gcc_r`: `RC=0`
  - `523.xalancbmk_r`: `RC=0`
  - `531.deepsjeng_r`: `RUN_RC=0`, `DIFF_RC=0`

Current implication:

- the logic line is no longer just "coverage plus assertions"
- adjacent `B.cond`, `CSEL/CS*`, and now `CCMP/CCMN` all have real
  host-flags-consuming fast paths
- the remaining logic-family headroom is now mostly:
  - stronger path-shape assertions / consolidation
  - or deciding whether to push beyond consumer-side fast paths into a new
    producer model

## Compare-Like `CSEL/CS* -> B.cond` Producer Rechain (First Slice)

On `2026-04-07`, the first "new producer model" slice landed in the working
tree:

- compare-like producer
- gap-safe consume into `CSEL/CS*`
- then immediate `B.cond`

What this slice does:

- after `CSEL/CS*` consumes a compare-like pending producer through the
  existing `CSEL-pending` path, it can now re-seed a fresh adjacent-only
  compare producer from the same `lhs/rhs/cc_op`
- the re-seeded producer is intentionally narrow:
  - only for flags-transparent `CSEL/CS*` consumers
  - only when the very next guest instruction is a plain `B.cond`
- this avoids reviving the older unsafe "peek and keep alive" model; the
  original compare is still retired to split flags first, and only then is a
  new adjacent producer recorded for the next direct branch consumer

What this slice does not try to do:

- it does not rechain across a gap after `CSEL/CS*`
- it does not yet rechain into a second `CSEL/CS*` or into `CCMP/CCMN`
- it does not alter the logic-producer host-flags line

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-csel-bcond-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-csel-bcond-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-csel-bcond-chain-host-direct.sh`: PASS
- `cmp-csel-bcond-chain-host-direct`: `RC=0`
- `check-cmp-csel-gap-host-direct.sh`: PASS
- `check-cmp-bcond-gap-host-direct.sh`: PASS
- `check-logic-csel-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - `makerand.out`: matches reference
  - `test.out`: still fails through the known perl wrapper / symlink issue
    (`Syntax error: "(" unexpected`), so this remains the same class of
    limitation already called out in the performance report
- `502.gcc_r`: `RUN_RC=0`
- `505.mcf_r`: `RUN_RC=0`, output matches reference
- `531.deepsjeng_r`: `RUN_RC=0`, output matches reference
- `541.leela_r`: `RUN_RC=0`, output matches reference
- `557.xz_r`: `RUN_RC=0`

Notes from the SPEC rerun:

- the copied-run `specdiff` invocations in this environment could not load
  `compare.pl`, so final output checks for `505/531/541` were confirmed with
  direct file diffs instead
- the resident `502.gcc_r` reference `.s` file under the original run
  directory is stale/truncated (only the first `.file` line), so it was not a
  useful correctness oracle; the meaningful result there is the successful
  compiler run itself

Current implication:

- the tree now has the first explicit producer-rechain step beyond pure
  consumer-side fast paths
- the next natural extension, if more chaining is wanted, is:
  - `CSEL/CS* -> CCMP/CCMN`
  - or a wider rechain policy than "immediate `B.cond` only"

## Compare-Like `CSEL/CS* -> CCMP/CCMN` Producer Rechain

Later on `2026-04-07`, the next adjacent producer-rechain slice landed:

- compare-like producer
- gap-safe consume into `CSEL/CS*`
- then immediate `CCMP/CCMN`

What changed:

- widened the `CSEL/CS*` compare-like rechain gate so it can re-seed a fresh
  adjacent compare producer not only for immediate `B.cond`, but also for an
  immediate plain `CCMP/CCMN`
- kept the same safety model as the prior slice:
  - the original compare-like pending producer is still retired to split flags
  - the re-seeded producer is still adjacent-only
  - no gap after `CSEL/CS*` is allowed

What this slice still does not try to do:

- it does not rechain across a blocker after `CSEL/CS*`
- it does not yet rechain into a second `CSEL/CS*`
- it does not try to keep `CCMP/CCMN` themselves as another new producer

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-csel-ccmp-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-csel-ccmp-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-csel-ccmp-chain-host-direct.sh`: PASS
- `cmp-csel-ccmp-chain-host-direct`: `RC=0`
- `check-cmp-csel-bcond-chain-host-direct.sh`: PASS
- `cmp-csel-bcond-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-gap-host-direct.sh`: PASS
- `check-logic-csel-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - `RUN_RC=0`
  - `makerand.out`: matches reference
  - `test.out`: still differs only through the known perl wrapper / symlink
    failure (`Syntax error: "(" unexpected`)
- `502.gcc_r`: `RUN_RC=0`, generated assembly has `21` lines
- `505.mcf_r`: `RUN_RC=0`, both output files match reference
- `531.deepsjeng_r`: `RUN_RC=0`, output matches reference
- `541.leela_r`: `RUN_RC=0`, output matches reference
- `557.xz_r`: `RUN_RC=0`

Current implication:

- compare-like rechain is no longer limited to `... -> B.cond`
- the next natural extension, if this line keeps expanding, is now either:
  - `CSEL/CS* -> second CSEL/CS*`
  - or making `CCMP/CCMN` themselves participate as a fresh producer stage

## Compare-Like `CSEL/CS* -> CSEL/CS*` Producer Rechain

On `2026-04-08`, the next producer-model slice landed, and this one is
intentionally stronger than the previous adjacent `... -> B.cond` and
`... -> CCMP/CCMN` slices.

What makes it stronger in theory:

- the previous slices still treated the first transparent `CSEL/CS*` consumer
  as the last non-branch hop before a terminal branch-or-CCMP consumer
- this slice allows the same compare-like producer to survive one more
  flags-transparent `CSEL/CS*` hop
- in practice that means one compare can now pay for:
  - first transparent consumer
  - second transparent consumer
  - and then, through the already-landed adjacent rechain logic on the second
    `CSEL/CS*`, an immediate `B.cond` or `CCMP/CCMN`

What changed:

- widened the compare-like transparent-consumer rechain gate again so an
  immediate second `CSEL/CS*` is now considered a valid adjacent re-seed
  target
- kept the same safety model as before:
  - the original compare-like producer is still retired to stable split flags
  - each re-seeded producer is still adjacent-only
  - no gap is allowed after a transparent consumer if the chain is to continue

What this slice still does not try to do:

- it does not rechain across a blocker after either `CSEL/CS*`
- it does not yet keep `CCMP/CCMN` results as another new producer stage
- it does not widen the lifetime model beyond repeated adjacent hops

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-csel-csel-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-csel-csel-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-csel-csel-chain-host-direct.sh`: PASS
- `cmp-csel-csel-chain-host-direct`: `RC=0`
- `check-cmp-csel-bcond-chain-host-direct.sh`: PASS
- `check-cmp-csel-ccmp-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.007.*`

Current implication:

- compare-like producer rechain is no longer just "one transparent consumer
  plus one terminal consumer"
- the tree now has the first explicit multi-hop transparent-consumer producer
  chain
- the next meaningful step, if the producer-model line continues, is more
  likely:
  - `CCMP/CCMN` as a fresh producer stage
  - or a dedicated perf rerun to see whether this stronger shape actually moves
    the workloads that regressed before

## `CCMP/CCMN -> B.cond` Producer Stage (First Slice)

Later on `2026-04-08`, the first `CCMP/CCMN` producer-stage slice landed.

What makes it stronger in theory than the previous `CSEL/CS* -> CSEL/CS*`
rechain slice:

- the previous slice still ended at a terminal consumer after the second
  transparent hop
- this slice turns a previously terminal consumer family (`CCMP/CCMN`) into a
  fresh producer stage of its own
- in the positive shape, the chain is now:
  - compare-like producer
  - `CCMP/CCMN` consumes the prior flags to choose between literal NZCV and
    computed add/sub NZCV
  - instead of immediately materializing canonical raw NZCV, it records that
    conditional add/sub result as a fresh adjacent-only producer
  - immediate `B.cond` consumes that fresh producer directly

What changed:

- when `CCMP/CCMN` sees that the very next guest instruction is a plain
  `B.cond`, it no longer eagerly writes canonical raw NZCV
- instead it records a fresh adjacent-only conditional add/sub producer:
  - computed path is still `rn +/- y`
  - false path is still the literal `nzcv`
  - the branch then consumes that producer through a dedicated
    `B.cond-CCMP-pending` path
- the older pending producer that fed the `CCMP/CCMN` condition is retired
  before the new producer is recorded, so the handoff remains explicit and
  traceable

What this slice still does not try to do:

- it does not extend `CCMP/CCMN` producer stage beyond immediate `B.cond`
- it does not yet let `CCMP/CCMN` feed `CSEL/CS*` or another `CCMP/CCMN`
- it does not try to express this stage as a new live-host-flags direct path;
  this first slice is still a symbolic producer consumed by generic branch TCG

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-bcond-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-bcond-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-bcond-chain-host-direct.sh`: PASS
- `cmp-ccmp-bcond-chain-host-direct`: `RC=0`
- `check-cmp-csel-csel-chain-host-direct.sh`: PASS
- `check-cmp-csel-ccmp-chain-host-direct.sh`: PASS
- `check-cmp-csel-bcond-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.008.*`

Current implication:

- `CCMP/CCMN` is no longer only a terminal non-branch consumer in this tree
- the producer-model line now includes both:
  - extra transparent-consumer lifetime via `CSEL/CS* -> CSEL/CS*`
  - and the first terminal-consumer-to-producer promotion via
    `CCMP/CCMN -> B.cond`
- the next meaningful extension, if this line keeps moving, is now more likely:
  - `CCMP/CCMN -> CSEL/CS*`
  - or `CCMP/CCMN -> CCMP/CCMN`

## `CCMP/CCMN -> CSEL/CS* -> B.cond` Producer Rechain

Later on `2026-04-08`, the next slice extended the `CCMP/CCMN` producer stage
through one flags-transparent `CSEL/CS*` hop and back into immediate
`B.cond`.

What makes it stronger in theory than the previous `CCMP/CCMN -> B.cond`
slice:

- the previous slice promoted `CCMP/CCMN` into a producer, but that producer
  still died immediately at the next branch
- this slice lets the same `CCMP/CCMN` result survive one more
  flags-transparent consumer before the eventual branch
- in the positive shape, the chain is now:
  - compare-like producer
  - `CCMP/CCMN` consumes the prior flags and records a conditional add/sub
    producer instead of canonical raw NZCV
  - immediate `CSEL/CS*` consumes that conditional producer through a dedicated
    `CSEL-CCMP-pending` path
  - after retiring stable split flags for generic readers, `CSEL/CS*`
    re-seeds one more adjacent-only conditional producer
  - immediate `B.cond` then direct-consumes that re-seeded producer through
    `B.cond-CCMP-pending`

What changed:

- `CCMP/CCMN` no longer keeps its conditional result symbolic only for
  immediate `B.cond`
- it now also keeps that result symbolic when the very next guest instruction
  is a plain `CSEL/CS*`
- `trans_CSEL()` learned a dedicated `conditional pending -> cond bool ->
  split flags` consume path:
  - it computes the computed-arm NZCV bits
  - selects computed-vs-literal NZCV using the original `CCMP/CCMN` selector
  - derives the `CSEL/CS*` condition from those effective NZCV bits
  - retires the old pending producer cleanly into split flags
- when that `CSEL/CS*` is followed immediately by plain `B.cond`, it re-seeds
  one more adjacent-only conditional producer instead of stopping at split
  flags
- compare-only helper entry points were tightened so the new conditional
  producer kind cannot accidentally flow through the older rewindable-compare
  helpers

What this slice still does not try to do:

- no `CCMP/CCMN -> CSEL/CS* -> CSEL/CS*` yet
- no `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN` yet
- no `CCMP/CCMN -> CCMP/CCMN` yet
- no gap-tolerant rechain after the `CSEL/CS*` hop
- no new live-host-flags direct path here; this is still a symbolic pending
  producer line

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-csel-bcond-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-csel-bcond-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS
- `cmp-ccmp-csel-bcond-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-bcond-chain-host-direct.sh`: PASS
- `check-cmp-csel-csel-chain-host-direct.sh`: PASS
- `check-cmp-csel-ccmp-chain-host-direct.sh`: PASS
- `check-cmp-csel-bcond-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.009.*`

Current implication:

- `CCMP/CCMN` producer stage is no longer just `-> immediate B.cond`
- it can now survive one flags-transparent `CSEL/CS*` hop and still feed the
  next branch
- the active producer-model line now has both:
  - compare-like producer rechain through `CSEL/CS*`
  - and `CCMP/CCMN` producer-stage rechain through `CSEL/CS*`
- the next meaningful extension, if this line keeps moving, is now more likely:
  - `CCMP/CCMN -> CSEL/CS* -> CSEL/CS*`
  - `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN`
  - or direct `CCMP/CCMN -> CCMP/CCMN`

## `CCMP/CCMN -> CSEL/CS* -> CSEL/CS* -> B.cond` Rechain

Still on `2026-04-08`, the next slice widened the `CCMP/CCMN` producer-stage
line by one more transparent hop.

What makes it stronger in theory than the previous
`CCMP/CCMN -> CSEL/CS* -> B.cond` slice:

- the previous slice let one `CCMP/CCMN` result survive through exactly one
  flags-transparent `CSEL/CS*` hop before the eventual branch
- this slice lets that same `CCMP/CCMN` result survive through a second
  adjacent `CSEL/CS*` hop before the branch
- in the positive shape, the chain is now:
  - compare-like producer
  - `CCMP/CCMN`
  - first `CSEL/CS*`
  - second `CSEL/CS*`
  - immediate `B.cond`

What changed:

- conditional pending producers created by `CCMP/CCMN` are no longer limited to
  "`next is plain B.cond`" after a transparent `CSEL/CS*` consume
- after the first `CSEL/CS*` consumes a conditional pending producer and
  retires stable split flags, it may now re-seed one more adjacent-only
  conditional producer when the very next guest instruction is another plain
  `CSEL/CS*`
- the second `CSEL/CS*` then consumes that re-seeded producer through the same
  `CSEL-CCMP-pending` path, and if the next guest instruction is immediate
  `B.cond`, it re-seeds one more conditional producer for the branch
- this keeps the implementation on the same narrow methodology:
  - still adjacent-only
  - still explicit retire-and-reseed between hops
  - still no new live-host-flags path

What this slice still does not try to do:

- no `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN` yet
- no direct `CCMP/CCMN -> CCMP/CCMN` yet
- no gap-tolerant rechain after any transparent hop
- no attempt to turn this into a heuristic or TB-level scheme

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-csel-csel-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-csel-csel-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-csel-csel-chain-host-direct.sh`: PASS
- `cmp-ccmp-csel-csel-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-bcond-chain-host-direct.sh`: PASS
- `check-cmp-csel-csel-chain-host-direct.sh`: PASS
- `check-cmp-csel-bcond-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.010.*`

Current implication:

- the `CCMP/CCMN` producer-stage line now has explicit focused evidence for:
  - `-> immediate B.cond`
  - `-> immediate CSEL/CS* -> immediate B.cond`
  - `-> immediate CSEL/CS* -> immediate CSEL/CS* -> immediate B.cond`
- the transparent-consumer side is no longer just compare-like-only; the same
  multi-hop model is now demonstrated for the promoted `CCMP/CCMN` producer
- the next meaningful extension, if this line keeps moving, is more likely:
  - `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN`
  - or direct `CCMP/CCMN -> CCMP/CCMN`

## `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond` Rechain

Later on `2026-04-08`, the next slice extended the promoted `CCMP/CCMN`
producer line from "another transparent consumer" into "transparent consumer
then another terminal consumer".

What makes it stronger in theory than the previous
`CCMP/CCMN -> CSEL/CS* -> CSEL/CS* -> B.cond` slice:

- the previous slice kept the same conditional producer alive through one more
  transparent hop, but still ended at a branch
- this slice lets that producer survive one transparent `CSEL/CS*` hop and then
  feed a second `CCMP/CCMN`
- the second `CCMP/CCMN` computes a fresh conditional add/sub result, so the
  chain now includes one more explicit terminal-consumer-to-producer handoff

What changed:

- `a64_test_cc_bool_i32()` learned how to read a conditional pending producer
  directly, without forcing it through raw flags first
- this lets `trans_CCMP()` use a re-seeded conditional producer as its own
  condition source
- after a conditional pending producer is consumed by `CSEL/CS*`, that
  transparent consumer may now re-seed one more adjacent-only conditional
  producer when the next guest instruction is immediate `CCMP/CCMN`
- in the positive shape the chain is now:
  - compare-like producer
  - first `CCMP/CCMN`
  - `CSEL/CS*`
  - second `CCMP/CCMN`
  - immediate `B.cond`

What this slice still does not try to do:

- no direct `CCMP/CCMN -> CCMP/CCMN` yet
- no `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> CSEL/CS*` yet
- no gap-tolerant rechain after the transparent hop
- no new live-host-flags path here; this is still the symbolic producer line

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-csel-ccmp-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-csel-ccmp-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-csel-ccmp-chain-host-direct.sh`: PASS
- `cmp-ccmp-csel-ccmp-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-csel-csel-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-bcond-chain-host-direct.sh`: PASS
- `check-cmp-csel-csel-chain-host-direct.sh`: PASS
- `check-cmp-csel-ccmp-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.011.*`

Current implication:

- the promoted `CCMP/CCMN` producer line now has focused evidence for:
  - `CCMP/CCMN -> CSEL/CS* -> B.cond`
  - `CCMP/CCMN -> CSEL/CS* -> CSEL/CS* -> B.cond`
  - `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond`
- the next meaningful extension is no longer "one more transparent hop" first;
  it is more likely:
  - direct `CCMP/CCMN -> CCMP/CCMN`
  - or `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> CSEL/CS*`

## `CCMP/CCMN -> CCMP/CCMN -> B.cond` Direct Rechain

Later on `2026-04-08`, the next slice extended the promoted `CCMP/CCMN`
producer line into a direct terminal-consumer-to-terminal-consumer handoff,
without requiring an intermediate transparent `CSEL/CS*`.

What makes it stronger in theory than the previous
`CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond` slice:

- the previous slice still needed one transparent `CSEL/CS*` hop in the middle
  before reaching the second terminal consumer
- this slice removes that middle hop and lets the first `CCMP/CCMN` feed the
  second `CCMP/CCMN` directly
- the chain now carries the promoted conditional producer through:
  - compare-like producer
  - first `CCMP/CCMN`
  - second `CCMP/CCMN`
  - immediate `B.cond`
- that is a stronger producer-lifetime result than "terminal -> transparent ->
  terminal", because the same model now supports "terminal -> terminal"
  directly

What changed:

- `trans_CCMP()` now treats an immediate plain `CCMP/CCMN` as another safe
  reason to keep the current conditional producer symbolic instead of retiring
  it into canonical raw NZCV
- the existing conditional-pending condition path in `a64_test_cc_bool_i32()`
  is now exercised by a second adjacent `CCMP/CCMN`, not only by a transparent
  `CSEL/CS*`
- the positive shape is now:
  - compare-like producer
  - first `CCMP/CCMN`
  - second `CCMP/CCMN`
  - immediate `B.cond`, consumed via the existing `B.cond-CCMP-pending` path

What this slice still does not try to do:

- no focused evidence yet for `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS*`
- no focused evidence yet for `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN`
- no gap-tolerant rechain across the direct `CCMP/CCMN -> CCMP/CCMN` handoff
- no new live-host-flags path here; this is still the symbolic producer line

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-ccmp-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-ccmp-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-ccmp-chain-host-direct.sh`: PASS
- `cmp-ccmp-ccmp-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-csel-ccmp-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-csel-csel-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-bcond-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.012.*`

Current implication:

- the promoted `CCMP/CCMN` producer line now has focused evidence for:
  - `CCMP/CCMN -> B.cond`
  - `CCMP/CCMN -> CSEL/CS* -> B.cond`
  - `CCMP/CCMN -> CSEL/CS* -> CSEL/CS* -> B.cond`
  - `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond`
  - direct `CCMP/CCMN -> CCMP/CCMN -> B.cond`
- the next meaningful extension is no longer "prove that direct `CCMP` handoff
  exists at all"; it is more likely:
  - `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`
  - or direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`

## `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond` Direct-Then-Transparent Rechain

Still on `2026-04-08`, the next slice pushed the new direct `CCMP/CCMN` line
one hop further by proving that a direct terminal-to-terminal handoff can then
survive one more transparent `CSEL/CS*` consumer before the eventual branch.

What makes it stronger in theory than the previous
`CCMP/CCMN -> CCMP/CCMN -> B.cond` slice:

- the previous slice proved only that the direct `CCMP/CCMN -> CCMP/CCMN`
  handoff exists and can terminate at an immediate branch
- this slice proves that the same direct handoff does not have to retire at the
  branch; it can continue through one more flags-transparent `CSEL/CS*` hop
- the chain now carries the promoted conditional producer through:
  - compare-like producer
  - first `CCMP/CCMN`
  - second `CCMP/CCMN`
  - `CSEL/CS*`
  - immediate `B.cond`
- that is stronger than the prior direct slice because one direct
  terminal-to-terminal handoff now composes with the already-landed
  transparent-consumer rechain instead of stopping there

What changed:

- no new translator or backend logic was needed for this slice
- the existing direct `CCMP/CCMN -> CCMP/CCMN` keep-pending rule in
  `trans_CCMP()` and the existing `CSEL-CCMP-pending` consume-plus-reseed path
  in `trans_CSEL()` already compose into this stronger shape
- this round therefore adds focused proof that the current producer model is
  already general enough to grow from:
  - direct `CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - into direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`

What this slice still does not try to do:

- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* ->
  CSEL/CS* -> B.cond`
- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* ->
  CCMP/CCMN -> B.cond`
- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN ->
  B.cond`
- no gap-tolerant rechain across the direct `CCMP/CCMN -> CCMP/CCMN` handoff
  or after the transparent hop

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-ccmp-csel-bcond-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS
- `cmp-ccmp-ccmp-csel-bcond-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-ccmp-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.013.*`

Current implication:

- the direct `CCMP/CCMN -> CCMP/CCMN` line no longer has focused evidence only
  for an immediate branch endpoint
- it now has focused evidence for:
  - direct `CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`
- that is a useful signal that the current producer-model rules are starting to
  compose without one new translator patch per chain shape
- the next meaningful extension is more likely:
  - direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - or direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond`

## `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond` Direct Triple-Terminal Rechain

Still on `2026-04-08`, the next slice pushed the same direct `CCMP/CCMN` line
one more step by proving that the direct terminal-to-terminal handoff can be
repeated again before the branch endpoint.

What makes it stronger in theory than the previous
`CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond` slice:

- the previous slice proved that one direct `CCMP/CCMN -> CCMP/CCMN` handoff
  can survive one more transparent `CSEL/CS*` hop before the branch
- this slice proves that the direct terminal handoff itself can repeat again,
  without needing an intermediate transparent hop
- the chain now carries the promoted conditional producer through:
  - compare-like producer
  - first `CCMP/CCMN`
  - second `CCMP/CCMN`
  - third `CCMP/CCMN`
  - immediate `B.cond`
- that is stronger than the previous slice because the current model now
  supports two successive direct terminal-to-terminal handoffs in one chain

What changed:

- no new translator or backend logic was needed for this slice either
- the existing direct `CCMP/CCMN -> CCMP/CCMN` keep-pending rule in
  `trans_CCMP()` already composes recursively into one more terminal handoff
- this round therefore adds focused proof that the same producer model grows
  from:
  - direct `CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - to direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
- in other words, the current line is no longer just "direct handoff exists";
  it is "direct handoff can be chained again"

What this slice still does not try to do:

- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN ->
  CSEL/CS* -> B.cond`
- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN ->
  CCMP/CCMN -> B.cond`
- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN ->
  CSEL/CS* -> CCMP/CCMN -> B.cond`
- no gap-tolerant rechain across the second direct `CCMP/CCMN` handoff

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-ccmp-ccmp-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-ccmp-ccmp-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-ccmp-ccmp-chain-host-direct.sh`: PASS
- `cmp-ccmp-ccmp-ccmp-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-ccmp-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.014.*`

Current implication:

- the direct `CCMP/CCMN -> CCMP/CCMN` line no longer stops at "one direct
  handoff plus one consumer"
- it now has focused evidence for:
  - direct `CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`
  - direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
- that is a stronger signal that the producer-model rules are recursive enough
  to keep composing across repeated terminal consumers
- the next meaningful extension is more likely:
  - direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`
  - or direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`

## `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond` Direct Triple-Terminal-Then-Transparent Rechain

Still on `2026-04-08`, the next slice pushed the same direct `CCMP/CCMN` line
one step further by proving that a triple-terminal chain can still survive one
more transparent `CSEL/CS*` hop before the branch endpoint.

What makes it stronger in theory than the previous
`CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond` slice:

- the previous slice proved that the direct terminal handoff can repeat again
  before the branch
- this slice proves that the resulting triple-terminal chain does not have to
  stop there; it can still compose with one more flags-transparent `CSEL/CS*`
  hop
- the chain now carries the promoted conditional producer through:
  - compare-like producer
  - first `CCMP/CCMN`
  - second `CCMP/CCMN`
  - third `CCMP/CCMN`
  - `CSEL/CS*`
  - immediate `B.cond`
- that is stronger than the previous slice because the recursive direct line
  now composes with the transparent rechain one level later

What changed:

- no new translator or backend logic was needed for this slice either
- the current direct `CCMP/CCMN -> CCMP/CCMN` keep-pending rule and the
  existing `CSEL-CCMP-pending` consume-plus-reseed path already compose into
  this stronger shape
- this round therefore adds focused proof that the current producer model grows
  from:
  - direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - into direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`

What this slice still does not try to do:

- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN ->
  CSEL/CS* -> CSEL/CS* -> B.cond`
- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN ->
  CSEL/CS* -> CCMP/CCMN -> B.cond`
- no focused evidence yet for direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN ->
  CCMP/CCMN -> B.cond`
- no gap-tolerant rechain across the transparent hop after the triple-terminal
  prefix

Files added for focused coverage:

- `tests/tcg/aarch64/cmp-ccmp-ccmp-ccmp-csel-bcond-chain-host-direct.S`
- `tests/tcg/aarch64/check-cmp-ccmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh`

Fresh focused evidence for this slice:

- `check-cmp-ccmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS
- `cmp-ccmp-ccmp-ccmp-csel-bcond-chain-host-direct`: `RC=0`
- `check-cmp-ccmp-ccmp-ccmp-chain-host-direct.sh`: PASS
- `check-cmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh`: PASS

CPU SPEC test-size regression spot-check after this slice:

- `500.perlbench_r`:
  - still the known nested-perl wrapper issue
  - `test.err` still shows repeated `Syntax error: "(" unexpected`
- `502.gcc_r`: `Success`
- `505.mcf_r`: `Success`
- `531.deepsjeng_r`: `Success`
- `541.leela_r`: `Success`
- `557.xz_r`: `Success`
- result bundle: `CPU2017.015.*`

Current implication:

- the recursive direct `CCMP/CCMN` line no longer has focused evidence only for
  pure terminal chains
- it now has focused evidence for:
  - direct `CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`
  - direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`
- that is a stronger signal that the producer-model rules are not merely
  recursive, but recursive and composable with later transparent consumers
- the next meaningful extension is more likely:
  - direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
  - or direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond`

## Current Scheme

As of `2026-04-08`, the active local line has three layers:

- compare-like producer line:
  - existing compare-like pending producer can still feed the restored
    compare-like `CSEL/CS*` path
  - after a flags-transparent `CSEL/CS*` consume, the translator can now
    re-seed a fresh adjacent-only compare producer for one more immediate
    consumer
- logic producer line:
  - adjacent `ANDS/TST -> B.cond`
  - adjacent `ANDS/TST -> CSEL/CSINV/CSET/CSETM/CSINC/CSNEG`
  - adjacent `ANDS/TST -> CCMP/CCMN`
- x86 backend support line:
  - `x86_jcc`
  - `x86_cmov`
  - `x86_add_noflags`
  - `x86_movi_noflags`

The current producer-rechain slices now cover:

- compare-like producer -> `CSEL/CS*` -> immediate `B.cond`
- compare-like producer -> `CSEL/CS*` -> immediate `CCMP/CCMN`
- compare-like producer -> `CSEL/CS*` -> immediate `CSEL/CS*`
- `CCMP/CCMN` -> immediate `B.cond` producer stage
- `CCMP/CCMN` -> immediate `CSEL/CS*` -> immediate `B.cond`
- `CCMP/CCMN` -> immediate `CSEL/CS*` -> immediate `CSEL/CS*` -> immediate
  `B.cond`
- `CCMP/CCMN` -> immediate `CSEL/CS*` -> immediate `CCMP/CCMN` -> immediate
  `B.cond`
- `CCMP/CCMN` -> immediate `CCMP/CCMN` -> immediate `B.cond`
- `CCMP/CCMN` -> immediate `CCMP/CCMN` -> immediate `CSEL/CS*` -> immediate
  `B.cond`
- `CCMP/CCMN` -> immediate `CCMP/CCMN` -> immediate `CCMP/CCMN` -> immediate
  `B.cond`
- `CCMP/CCMN` -> immediate `CCMP/CCMN` -> immediate `CCMP/CCMN` -> immediate
  `CSEL/CS*` -> immediate `B.cond`

The current boundaries are still deliberate:

- all new chaining is adjacent-only, whether it happens after `CSEL/CS*` or
  across a direct `CCMP/CCMN` handoff
- no rechain across a gap after the transparent consumer
- `CCMP/CCMN` producer stage currently reaches:
  - immediate `B.cond`
  - immediate `CSEL/CS*`, with one more rechain only when that `CSEL/CS*` is
    immediately followed by plain `B.cond`, plain `CSEL/CS*`, or plain
    `CCMP/CCMN`
  - immediate `CCMP/CCMN`, with focused evidence today only for an immediate
    trailing plain `B.cond`, plain `CSEL/CS* -> B.cond`, or another plain
    `CCMP/CCMN -> B.cond`, or `CCMP/CCMN -> CSEL/CS* -> B.cond`
- `CCMP/CCMN -> CSEL/CS* -> CSEL/CS*` now exists in the adjacent-only
  producer-rechain line
- `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN` now exists in the adjacent-only
  producer-rechain line
- direct `CCMP/CCMN -> CCMP/CCMN` now exists in the adjacent-only
  producer-rechain line, with focused evidence today for a trailing plain
  `B.cond`, for `CSEL/CS* -> B.cond`, and for another plain
  `CCMP/CCMN -> B.cond`
- direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN` now exists in the same
  adjacent-only producer-rechain line, with focused evidence today for a
  trailing plain `B.cond` and for `CSEL/CS* -> B.cond`
- no focused `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> CSEL/CS*` yet
- no focused `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN` yet
- no focused `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS*` yet
- no focused `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN` yet
- no TB-level gating or heuristic disablement in this line

The working assumption behind the current direction is:

- perf does not look like a pure "add more one-shot consumers" problem
- the next plausible gain is to let one producer pay for multiple downstream
  consumers instead of retiring after the first non-branch hit

## Next Plan

The next implementation work should stay on the new producer-model line before
branching into broader heuristics.

Priority order:

- first priority: extend the new triple-terminal line by one more terminal
  handoff, starting with direct
  `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
- second priority: once that four-terminal chain is green, decide whether the
  next strongest proof should be direct
  `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond`
- third priority: only after one more direct-`CCMP` extension and another perf
  measurement should we decide whether a different producer family is still the
  right next expansion

What is explicitly not the near-term focus:

- TB-level opt-out or other broad gating heuristics
- widening the current rechain across arbitrary gaps
- starting a new producer family before the current producer-model line has a
  clearer perf signal

## Per-Slice Method

Each optimization slice should continue to follow the same workflow:

- keep the scope narrow:
  - one chain extension at a time
  - prefer adjacent-only first
  - only widen the lifetime model when the previous narrower shape is green
- preserve the safety model:
  - retire the original pending producer cleanly
  - then re-seed a new producer only when the next consumer shape is known and
    safe
  - avoid "peek and keep alive" style shortcuts
- pair every translator/backend change with focused coverage:
  - add one `.S` test that exercises the intended hit and the intended miss
  - add one checker that proves the wanted `OP:` or `OUT:` codegen shape
- run focused validation before broader regression:
  - targeted checker for the new slice
  - nearby older checkers that could regress
- after each new feature, run the six CPU SPEC test-size regressions:
  - `500.perlbench_r`
  - `502.gcc_r`
  - `505.mcf_r`
  - `531.deepsjeng_r`
  - `541.leela_r`
  - `557.xz_r`
- record the outcome in this file before moving to the next slice

Operational notes for the six-test rerun:

- `500.perlbench_r` still has the known wrapper/symlink issue on `test.out`;
  `makerand.out` is the useful stability signal there
- `502.gcc_r` should be judged by successful compile/run, not by the stale
  truncated resident reference `.s`
- if copied-run `specdiff` cannot resolve `compare.pl`, direct output diffs are
  acceptable for `505/531/541`

## Reference Docs

These documents are still useful background, but `progress.md` is now the main
day-to-day handoff:

- [handoff.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/archive/handoff.md)
- [codex_a64_x86_status4_handoff.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/archive/codex_a64_x86_status4_handoff.md)
- [2026-04-01-direct-path-candidate-matrix.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/archive/2026-04-01-direct-path-candidate-matrix.md)
- [2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/summaries/2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md)
- [2026-04-02-spec-cpu2017-seven-test-size-runbook.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/summaries/2026-04-02-spec-cpu2017-seven-test-size-runbook.md)
- [2026-04-02-worktree-closure-and-merge-strategy.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/summaries/2026-04-02-worktree-closure-and-merge-strategy.md)
- [2026-04-01-lazy-compare-phase-2-bcond.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/archive/2026-04-01-lazy-compare-phase-2-bcond.md)
- [2026-04-01-lazy-compare-phase-2-design.md](/home/ruoyu/code/qemu_nzcv/qemu10.2/docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md)

## 2026-04-09 Deferred-Flags Main-Representation Slice: `B.cond`

This slice moved plain compare-like `B.cond` gap consumers off the old
pairwise `pending_cc` contract and onto the current main flags representation.

What changed:

- `B.cond` still keeps the adjacent same-guest-insn compare fast path:
  - plain adjacent compare-like producer -> plain `B.cond`
  - this remains on the old direct lowering path
- gap compare-like `B.cond` no longer consumes old compare-like `pending_cc`:
  - if the branch is not immediately after the producer in guest-PC terms,
    the translator now falls back to reading the current main representation
    (`RAW` or `SPLIT`)
- conditional `CCMP/FCCMP -> B.cond` pending handling is unchanged in this
  slice:
  - the specialized conditional-pending branch path stays in place
- to make the new branch path correct, lazy gap producers now publish durable
  main flags when needed:
  - compare-like `CMP/SUBS/CMN/ADDS` lazy `B.cond` gap producers now publish
    main flags for non-adjacent gap cases
  - `ADCS/SBCS rd==xzr` lazy `B.cond` gap producers now also publish durable
    raw main flags for non-adjacent gap cases

Focused checker change:

- `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh` now encodes the new
  contract:
  - gap positives may still record a pending producer
  - but they must not consume that old producer
  - the branch block must instead read current `x86_raw_flags` and branch via
    the main representation
  - the plain adjacent precedence case still requires the old direct fast path

Why this slice matters:

- it removes one of the biggest remaining sources of miss-sensitive behavior:
  plain gap `B.cond` no longer needs the old producer/consumer pairing to get
  correct fast-path behavior
- it keeps the most valuable immediate branch case narrow:
  only truly adjacent guest compare -> branch keeps the old direct lowering
- it exposes which producer families still need explicit main-state publish
  support instead of silently relying on pairwise pending consumption

Verification after this slice:

- focused branch checks:
  - `check-cmp-bcond-gap-host-direct.sh`
  - `check-cmp-bcond-ext-host-direct.sh`
  - `check-cmp-ccmp-bcond-chain-host-direct.sh`
  - `check-cmp-csel-bcond-chain-host-direct.sh`
  - `check-cmp-ccmp-csel-bcond-chain-host-direct.sh`
  - `check-cmp-ccmp-csel-ccmp-chain-host-direct.sh`
- shared regressions:
  - `nzcv-status4`: `PASS`
  - `check-nzcv-status4-raw-ccop-specialization.sh`: `PASS`
- SPEC CPU2017 `test` smoke using `config/qemu_aarch64_tcg.cfg` with the
  current main-branch `build-aarch64-linux-user/qemu-aarch64`:
  - `502.gcc_r`: `Success`
  - `505.mcf_r`: `Success`
  - `531.deepsjeng_r`: `Success`
  - `541.leela_r`: `Success`
  - `557.xz_r`: `Success`
  - result bundle: `CPU2017.106.*`
  - log: `/home/wangruoyu/cpuspec2017/result/CPU2017.106.log`

Current local conclusion:

- `CCMP/FCCMP` consumers already read main representation
- plain gap `B.cond` now reads main representation too
- the next main-representation consumer slice should be `CSEL/CS*` and then
  plain `ADC/SBC`, rather than extending the older producer-chaining line
  further first

Historical note:

- the older adjacent-only producer-chaining roadmap above remains useful
  background for already-landed chain coverage
- but the active local direction is now the deferred-flags main-representation
  migration described here and in
  `docs/superpowers/specs/2026-04-09-deferred-flags-main-representation-design.md`
