# Worktree Closure And Merge Strategy

## Goal

Capture the current integration state of the active worktree branch and define
what should happen next before any merge/cherry-pick decision is made.

This document is the `step 3` closure checkpoint for the current branch.

## Branches

Main workspace branch:

- repo: `/home/wangruoyu/qemu10.2`
- branch: `a64-x86-status4-v10.2.0`
- `HEAD`: `ffcf55b840`

Active worktree branch:

- path:
  `/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct`
- branch:
  `adcs-sbcs-producer-direct-v10.2.0`
- current `HEAD`:
  `5f350f8f0c`

Merge base between the worktree branch and the main workspace branch:

- `ffcf55b840`

So the current worktree-only code stack is:

- `d457c0747a` `aarch64: chain SUBS rd into gap CSEL aliases`
- `14703516aa` `aarch64: chain ADDS rd into gap CSEL aliases`
- `ac64c57b45` `aarch64: chain ADDS/SUBS rd into gap CCMP`
- `5f09260d2e` `aarch64: chain ADDS/SUBS rd into gap floating consumers`
- `80acb12aae` `aarch64: narrow add-like lazy B.cond conditions`
- `e3d336d0b1` `tests/aarch64: strengthen logic producer host-block assertions`
- `ae79dbc977` `aarch64: chain ADCS/SBCS rd into gap CSEL`
- `59bd0636f0` `aarch64: chain ADCS/SBCS rd into gap CCMP`
- `5f350f8f0c` `aarch64: chain ADCS/SBCS rd into gap floating consumers`

## What Is Good

Focused feature validation on the worktree tip is green:

- `check-subs-rd-csel-gap-host-direct.sh`
- `check-adds-rd-csel-gap-host-direct.sh`
- `check-subs-rd-ccmp-gap-host-direct.sh`
- `check-adds-rd-ccmp-gap-host-direct.sh`
- `check-subs-rd-fcsel-gap-host-direct.sh`
- `check-adds-rd-fcsel-gap-host-direct.sh`
- `check-subs-rd-fccmp-gap-host-direct.sh`
- `check-adds-rd-fccmp-gap-host-direct.sh`
- `check-cmp-csel-gap-host-direct.sh`
- `check-cmp-ccmp-gap-host-direct.sh`
- `check-cmp-fcsel-gap-host-direct.sh`
- `check-cmp-fccmp-gap-host-direct.sh`
- `check-adc-sbc-host-direct.sh`
- `check-adcs-rd-csel-gap-host-direct.sh`
- `check-sbcs-rd-csel-gap-host-direct.sh`
- `check-adcs-rd-ccmp-gap-host-direct.sh`
- `check-sbcs-rd-ccmp-gap-host-direct.sh`
- `check-adcs-rd-fcsel-gap-host-direct.sh`
- `check-sbcs-rd-fcsel-gap-host-direct.sh`
- `check-adcs-rd-fccmp-gap-host-direct.sh`
- `check-sbcs-rd-fccmp-gap-host-direct.sh`
- `nzcv-status4`

This means the newly added materialized producer paths are internally coherent
under the current focused asm/TCG checks.

## What Was Not Good

The branch was **not merge-ready** when this closure pass began.

The minimal perf/smoke closure run found that two broader benchmarks crash on
the worktree tip:

### On the worktree tip `5f09260d2e`

Commands:

```sh
cd /home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct
/usr/bin/time -f "adcsbc_time_sec %e" \
  ./build/qemu-aarch64 -cpu max \
  build/tests/tcg/aarch64-linux-user/adcsbc-bench

/usr/bin/time -f "cmpstress_time_sec %e" \
  ./build/qemu-aarch64 -cpu max \
  build/tests/tcg/aarch64-linux-user/cmpstress-o3
```

Observed result:

- `adcsbc-bench`: `RC=139`, guest `SIGSEGV`
- `cmpstress-o3`: `RC=139`, guest `SIGSEGV`

### On the main workspace branch `ffcf55b840`

Commands:

```sh
cd /home/wangruoyu/qemu10.2
/usr/bin/time -f "main_adcsbc_time_sec %e" \
  ./build-aarch64-linux-user/qemu-aarch64 -cpu max \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench

/usr/bin/time -f "main_cmpstress_time_sec %e" \
  ./build-aarch64-linux-user/qemu-aarch64 -cpu max \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3
```

Observed result:

- `adcsbc-bench`: `RC=0`
- `cmpstress-o3`: `RC=0`

## Interpretation

This was the important first closure result:

- the worktree branch currently has a regression that is *not* covered by the
  focused asm/TCG tests
- the regression is visible on broader QEMU-side smoke/perf binaries
- therefore the worktree stack after `ffcf55b840` should **not** be merged yet

Further regression-debugging narrowed this down to the first bad commit:

- `6653c87c86` `aarch64: extend lazy compare B.cond add-side coverage`

This means the crash predates the later materialized non-branch producer work.
The later `CSEL` / `CCMP` / `FCSEL` / `FCCMP` materialized-producer commits are
currently sitting on top of a branch that was already unstable for
`adcsbc-bench` and `cmpstress-o3`.

The first-bad-commit diff touches:

- `target/arm/tcg/translate-a64.c`
- `tcg/i386/tcg-target-opc.h.inc`
- `tcg/i386/tcg-target.c.inc`
- `tcg/tcg.c`
- `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh`

That hypothesis was then tested and confirmed by a targeted fix:

- `80acb12aae` `aarch64: narrow add-like lazy B.cond conditions`

What the fix does:

- keeps add/adc-like lazy `B.cond` direct support only for conditions whose
  semantics match x86 add/adc flags directly:
  - `EQ/NE`
  - `MI/PL`
  - `VS/VC`
  - `GE/LT/GT/LE`
- drops the unsafe carry/unsigned subset from the add-side direct path:
  - `CS/CC/HI/LS`

Post-fix closure evidence on the feature worktree:

```sh
cd /home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct
./build/qemu-aarch64 -cpu max build/tests/tcg/aarch64-linux-user/adcsbc-bench
./build/qemu-aarch64 -cpu max build/tests/tcg/aarch64-linux-user/cmpstress-o3
bash tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
  ./build/qemu-aarch64 build/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
bash tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh \
  ./build/qemu-aarch64 build/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct
./build/qemu-aarch64 -cpu max build/tests/tcg/aarch64-linux-user/nzcv-status4
bash tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
  ./build/qemu-aarch64 build/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

Observed result:

- `adcsbc-bench`: `RC=0`
- `cmpstress-o3`: `RC=0`
- `check-cmp-bcond-gap-host-direct.sh`: PASS
- `check-cmp-bcond-ext-host-direct.sh`: PASS
- `nzcv-status4`: PASS
- `check-adc-sbc-host-direct.sh`: PASS

## Merge Strategy

Recommended strategy now:

1. **Do not merge anything before the fix commit is included**
   - the safe tip now includes:
     - `80acb12aae`
   - and the current fully validated feature tip is:
     - `5f350f8f0c`

2. **Keep the feature worktree branch intact**
   - preserve:
     `/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct`
   - it now contains the full feature stack plus the regression fix

3. **It is still fine to merge documentation-only artifacts separately later**
   - examples:
     - progress/runbook/perlbench workaround notes
   - but only if you want doc sync independent of code sync

4. **The closure blocker is cleared**
   - broader smoke/perf closure is green again on the feature worktree
   - it is now reasonable to resume the planned post-closure work
   - carry-producer non-branch consumers are now also landed on top of the
     fixed branch line

## Recommended Next Step

The next engineering task should now be:

- decide whether to:
  - keep consolidating docs / merge preparation
  - or continue into a different optimization family

## Status Summary

Current branch status:

- focused feature tests: green
- wider smoke/perf closure: green again after `80acb12aae`
- merge readiness: improved, but still should be treated as a feature branch
- correct next action: **resume the planned non-feature cleanup work**
