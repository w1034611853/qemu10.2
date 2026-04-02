# Progress

This is the canonical progress tracker for the AArch64-on-x86 TCG direct-path
work in this repo.

From this point on, new progress updates should land here first. Older handoff,
matrix, and plan files remain useful as historical references, but this file is
the main running summary.

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
- current main `HEAD`: `ffcf55b840` (`chore: ignore project-local worktrees`)

Active isolated worktree:

- path:
  `/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct`
- branch:
  `adcs-sbcs-producer-direct-v10.2.0`
- current worktree `HEAD`:
  `5f350f8f0c` (`aarch64: chain ADCS/SBCS rd into gap floating consumers`)

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

## Latest Worktree Commits

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

These focused checks are currently green on the active worktree tip:

```bash
ninja -C build qemu-aarch64
tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct
tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct
tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
./build/qemu-aarch64 -cpu max \
    build/tests/tcg/aarch64-linux-user/nzcv-status4
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

## Old Docs Now Folded Into This One

The following files are still useful references, but this file replaces them as
the main day-to-day progress tracker:

- [handoff.md](/home/wangruoyu/qemu10.2/handoff.md)
- [codex_a64_x86_status4_handoff.md](/home/wangruoyu/qemu10.2/codex_a64_x86_status4_handoff.md)
- [2026-04-01-direct-path-candidate-matrix.md](/home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-01-direct-path-candidate-matrix.md)
- [2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md](/home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md)
- [2026-04-02-spec-cpu2017-seven-test-size-runbook.md](/home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-02-spec-cpu2017-seven-test-size-runbook.md)
- [2026-04-02-worktree-closure-and-merge-strategy.md](/home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-02-worktree-closure-and-merge-strategy.md)
- [2026-04-01-lazy-compare-phase-2-bcond.md](/home/wangruoyu/qemu10.2/docs/superpowers/plans/2026-04-01-lazy-compare-phase-2-bcond.md)
- [2026-04-01-lazy-compare-phase-2-design.md](/home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md)

## Current Coding Starting Point

The next implementation work should begin from the clean worktree:

- branch: `adcs-sbcs-producer-direct-v10.2.0`
- tip: `5f350f8f0c`
- target area:
  - `target/arm/tcg/translate-a64.c`
  - `tests/tcg/aarch64/`

The immediate question after this point is no longer whether the carry
producer family can be extended to the current non-branch consumers; that work
is now in place too.

The next likely directions are now:

- deeper assertion tightening / consolidation
- broader perf closure and merge preparation
- or a different consumer family entirely
