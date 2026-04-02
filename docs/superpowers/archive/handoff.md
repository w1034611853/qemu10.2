> Archive: historical handoff note kept for reference. Current status and
> active feature coverage now live in `progress.md`.

# Current Handoff

## Repo State

### Main workspace

- Repo: `/home/wangruoyu/qemu10.2`
- Branch: `a64-x86-status4-v10.2.0`
- Current `HEAD`: `ffcf55b840` (`chore: ignore project-local worktrees`)
- Local branch status: ahead of `origin/a64-x86-status4-v10.2.0`

Main workspace now contains the documentation / planning commits for the next phase,
plus the earlier committed `ADCS/SBCS` closure work:

- `ca62179ee1` `aarch64: close ADCS/SBCS direct-consumer validation gaps`
- `bf6eb94600` `docs: add direct-path candidate matrix`
- `d1ed536bcc` `docs: add next direct-path and lazy-compare specs`
- `ffcf55b840` `chore: ignore project-local worktrees`

There are many untracked local logs / generated binaries in the main workspace.
They were intentionally left untouched.

### Active isolated worktree

- Worktree path:
  `/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct`
- Branch:
  `adcs-sbcs-producer-direct-v10.2.0`
- Current `HEAD`:
  `996e400881` (`aarch64: chain SBCS rd into lazy B.cond`)

## What Is Finished

### 1. `ADCS/SBCS producer direct-consumer` line is functionally complete

This line was executed in the isolated worktree and is green after review.

Completed commit stack in the worktree:

- `302e934e0b` `tests/aarch64: expose ADCS/SBCS producer plain-consumer gaps`
- `fb8ca29c3f` `tests/aarch64: tighten phase A1 plain-consumer guards`
- `c6f44a4c07` `tests: relax mixed-width adc oracle, enforce adjacency`
- `0504c8a952` `tests: reset adjacency state, tighten mixed-width adc`
- `181ab31881` `tests: reset adjacency state in 3.1 extractors`
- `c34d03a289` `tests: init 3.1 adjacency extractor state`
- `f73df5e6e5` `tests: fix phase A1 adjacency resets and mixed-width glue oracle`
- `26017ec070` `aarch64: chain ADCS/SBCS into plain ADC/SBC`
- `0af3c14c8f` `aarch64: enforce same-width ADCS/SBCS phase A1 chains`
- `1b93cb5504` `tests/aarch64: expose ADCS/SBCS chain gaps`
- `e8948d7bfa` `tests/tcg/aarch64: isolate A2 host block extraction`
- `051fa713ca` `aarch64: chain ADCS/SBCS into ADCS/SBCS`
- `4427fbf9c1` `aarch64: keep ADCS/SBCS A2 off xzr consumers`

What is now working:

- Phase A1:
  - `ADCS/SBCS -> ADC/SBC`
- Phase A2:
  - `ADCS/SBCS -> ADCS/SBCS`

Scope that was deliberately preserved:

- same-TB only
- same-width only
- `rd != 31` only
- `xzr/wzr` setflags consumers are **not** admitted into phase A2 direct chaining

Verified commands in the worktree were green at the end of Task 5:

```bash
ninja -C build qemu-aarch64
make -C build/tests/tcg/aarch64-linux-user adc-sbc-host-direct nzcv-status4
tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
    ./build/qemu-aarch64 \
    build/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
./build/qemu-aarch64 build/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
./build/qemu-aarch64 -cpu max build/tests/tcg/aarch64-linux-user/nzcv-status4
```

Observed final state:

- host-direct checker: PASS
- `adc-sbc-host-direct`: exit code `0`
- `nzcv-status4`: `PASS`

Final review note:

- no concrete correctness bug was found in the implemented range
- only residual low-risk coverage suggestions remained
  - mirror producer-CF polarity coverage
  - broader mixed-width negative coverage

### 2. `lazy compare phase 2 B.cond` first rollout is now implemented and green

The second line is no longer sitting at Task 1 red harness status. The active
worktree now contains the first working `B.cond` rollout:

- `29f21e7534` `tests/aarch64: add lazy compare B.cond gap harness`
- `2464ce86a0` `tests/aarch64: tighten lazy compare gap invalidation coverage`
- `491e051771` `aarch64: make lazy compare B.cond lifetime explicit`
- `6653c87c86` `aarch64: extend lazy compare B.cond add-side coverage`
- `eece17cd54` `aarch64: extend add-like lazy B.cond jcc coverage`
- `05838b8e0a` `aarch64: chain ADCS xzr into lazy B.cond`
- `c23d399354` `aarch64: chain ADCS rd into lazy B.cond`
- `996e400881` `aarch64: chain SBCS rd into lazy B.cond`

What now works in the worktree:

- bounded-gap `CMP/SUBS xzr -> B.cond`
  - gap 1 / 4 / 8
- bounded-gap `CMN/ADDS xzr -> B.cond`
  - gap 1 / 4 / 8
  - condition coverage now includes:
    - `EQ/NE/CS/CC/HI/LS/GE/LT/GT/LE`
    - `MI/PL/VS/VC`
- bounded-gap `ADCS xzr -> B.cond`
  - verified for both TCG-cond and x86-jcc-only condition families in the
    dedicated gap harness
  - current implementation uses dedicated x86 `adc + brcond/jcc + rawflags`
    host ops and carries the producer carry-in through `pending_cc`
- bounded-gap `ADCS rd -> B.cond`
  - current rollout is deliberately scoped to non-adjacent gap cases
  - adjacent `ADCS rd` branch users still keep the old behavior
- bounded-gap `SBCS rd -> B.cond`
  - current rollout is likewise scoped to non-adjacent gap cases
- existing arithmetic direct-consumer work remains green while this is enabled

Current conservative invalidation behavior:

- non-whitelist gap instruction: no consume
- flags writer in the gap: no consume
- gap overflow (`> 8`): no consume
- page boundary / TB-style cut: producer may decline to record rather than
  record-then-drop
- direct control-flow cut: producer may decline to record rather than
  record-then-drop

Important nuance on adjacency:

- the current adjacent precedence case is validated as a direct `age=1`
  consume, not as an explicit `rewind`
- attempts to reintroduce the old rewind bookkeeping reopened the previous
  `temp_load: code should not be reached` runtime abort
- that rewind-only trace parity work is therefore deferred and should be treated
  as a follow-up, not part of the current stable rollout

## What Is In Progress Right Now

### No uncommitted translator WIP is left in the active worktree

`git status` in the worktree is now clean. The branch tip already contains the
validated `lazy compare phase 2 B.cond` changes listed above.

The next work should start from committed state `6653c87c86`, not from any old
dirty `translate-a64.c` snapshot.

## Suggested Next Step

### Immediate next action

Continue from the existing committed worktree branch at `6653c87c86`.

Recommended procedure:

1. Keep the current `cmp-bcond-gap` and `adc-sbc` focused checks green
2. Decide which follow-up slice has the best ROI
3. Land the next slice in the same worktree branch, or cherry-pick this branch
   back once you are ready

### Caution

The main remaining caution is scope, not cleanliness:

- add-side `B.cond` support is currently filtered to the TCG-mappable condition
  subset plus the x86-jcc-only family:
  - `MI/PL/VS/VC`
- explicit adjacent `rewind` trace parity is still deferred because it reopens
  the old runtime crash
- invalidation cases now model "no record/no use" for boundary and direct-cut
  cases; they no longer insist on record-then-drop

## Fresh Verification Evidence

These commands were rerun successfully in the active worktree after
`6653c87c86`:

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

Observed result:

- `check-cmp-bcond-gap-host-direct.sh`: PASS
- `cmp-bcond-gap-host-direct`: exit code `0`
- `nzcv-status4`: `PASS`
- `check-adc-sbc-host-direct.sh`: PASS
- `check-cmp-bcond-ext-host-direct.sh`: PASS

## Recommended Next Extensions

The best follow-on candidates after `6653c87c86` are:

1. Extend current materialized carry-producer branch coverage
   - 32-bit `ADCS/SBCS rd -> B.cond`
   - broader condition coverage if any gaps remain
2. Reuse the bounded lazy compare lifetime for non-branch consumers
   - `CSEL/CCMP/CS*`
3. Revisit explicit adjacent rewind bookkeeping only if you want trace parity
   badly enough to justify a dedicated runtime/debug pass

## Useful References

### Main docs / specs / plans

- `codex_a64_x86_status4_handoff.md`
- `docs/superpowers/summaries/2026-03-31-adcs-sbcs-direct-consumer-summary.md`
- `docs/superpowers/summaries/2026-03-31-adcs-sbcs-test-summary.md`
- `docs/superpowers/summaries/2026-04-01-direct-path-candidate-matrix.md`
- `docs/superpowers/specs/2026-04-01-adcs-sbcs-producer-direct-consumer-design.md`
- `docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md`
- `docs/superpowers/plans/2026-04-01-adcs-sbcs-producer-direct-consumer.md`
- `docs/superpowers/plans/2026-04-01-lazy-compare-phase-2-bcond.md`

### Most relevant branches / locations

- main repo branch:
  - `a64-x86-status4-v10.2.0`
- active worktree branch:
  - `adcs-sbcs-producer-direct-v10.2.0`

### Most relevant file under active development

- `/home/wangruoyu/qemu10.2/.worktrees/adcs-sbcs-producer-direct/target/arm/tcg/translate-a64.c`
