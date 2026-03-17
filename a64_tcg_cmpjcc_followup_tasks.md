# A64 TCG Compare/JCC Follow-up Tasks

## Goal

In the current `a64-x86-status4-v10.2.0` line, keep guest execution strictly correct while improving the host x86 lowering around AArch64 compare-like flag producers and their consumers.

All tasks below must obey one hard rule:

- correctness first: no optimization is allowed to change guest-visible architectural state, including NZCV, general-purpose registers, TB chaining behavior, or cross-TB flag consumers

## Global Correctness Requirements

Before marking any task complete:

- existing `tests/tcg/aarch64/nzcv-status4.S` must pass
- any new fast path must preserve all non-adjacent cases by falling back safely
- `out_asm` / `op` logs must confirm the intended fast path, not just functional equivalence
- no rewind/removal logic may delete unrelated IR

## Priority 1

### Task 1: Direct x86 JCC support for `MI/PL/VS/VC`

Current state:

- adjacent `CMP/SUBS + B.cond` already lowers to host x86 `cmp+jcc` for `EQ/NE/CS/CC/HI/LS/GE/LT/GT/LE`
- `MI/PL/VS/VC` still fall back through materialized canonical flags

Why this is first:

- it is local, high-value, and keeps the current correctness model intact
- it improves the remaining obvious hole in the adjacent branch fast path

Implementation target:

- add an x86-backend-only compare+raw-jcc op so `JS/JNS/JO/JNO` can be emitted directly
- keep the existing safe rewind gating: only adjacent compare+branch may use this path
- preserve canonical flag save on both branch edges

Acceptance:

- add dedicated adjacent tests for `CMP + B.mi/pl/vs/vc`
- `nzcv-status4` still passes
- `out_asm` must show direct host `cmp` followed by `js/jns/jo/jno`

Status:

- [x] completed

## Priority 2

### Task 2: Extend adjacent direct-path rewiring to non-branch consumers

Current state:

- `CSEL/FCSEL/CCMP/FCCMP` can already read pending compare operands directly
- but adjacent compare producers still eagerly generate split flags + canonical state before these consumers

Why this is second:

- likely meaningful performance gain
- still correctness-manageable because scope is limited to adjacent producer/consumer pairs

Implementation target:

- for strictly adjacent `CMP/SUBS` followed by `CSEL/FCSEL/CCMP/FCCMP`, reuse the rewind idea
- remove the eager compare-flag producer IR and emit only the consumer-specific direct compare path
- still materialize canonical state when architectural continuation requires it

Acceptance:

- add adjacency-focused tests for each covered consumer
- existing non-adjacent tests remain unchanged and passing
- `op/out_asm` logs must show the eager flag-producer block is gone in covered adjacent cases

Status:

- [x] completed

## Priority 3

### Task 3: Correctness-first lazy compare state

Current state:

- the implementation is still fundamentally eager-flag based
- adjacent `B.cond` is optimized by rewinding eager IR, but wider windows still pay the producer cost

Why this is third:

- highest potential gain
- also highest design risk
- should only begin after Priority 1 and 2 are stable and well-covered

Implementation target:

- introduce a bounded lazy compare-state design for compare-like producers
- allow non-flag-clobbering instructions between producer and consumer without losing optimization opportunities
- keep explicit invalidation whenever any instruction writes canonical/split flags in a way that ends the lazy state

Suggested rollout:

1. add instrumentation / counters to understand producer-consumer spacing
2. design a lazy compare record with explicit invalidation rules
3. switch one narrow consumer family at a time

Current correctness-first scope:

- phase 1 only adds translation-time instrumentation and TB summaries under `-d op`
- phase 1 must not widen lazy-state lifetime or change any guest-visible behavior
- semantic widening is deferred until the new logs show a safe next target

Acceptance:

- no semantic regressions in user-mode correctness tests
- cross-TB consumers remain correct
- design must include explicit invariants and invalidation rules

Status:

- [x] phase 1 instrumentation completed
- [ ] phase 2 lazy compare design
- [ ] phase 3 narrow semantic rollout
