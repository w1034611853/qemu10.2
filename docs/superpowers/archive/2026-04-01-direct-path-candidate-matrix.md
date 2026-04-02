> Archive: historical prioritization matrix kept for reference. The current
> project state now lives in `progress.md`.

# Direct-Path Candidate Matrix

## Goal

Provide a single prioritized view of the next direct-path candidates after the
current `ADCS/SBCS` closure, using three ranking axes:

- **Benefit**: likely performance upside or canonical-flags glue removed
- **Risk**: semantic and state-machine complexity
- **Continuity**: how naturally the work fits the current
  `pending_cc + raw/split flags + x86 host flags` framework

## Current Status Update

The original matrix was written before the first `lazy compare phase 2 B.cond`
rollout landed in the active worktree. That rollout now exists at:

- `6653c87c86` `aarch64: extend lazy compare B.cond add-side coverage`
- `eece17cd54` `aarch64: extend add-like lazy B.cond jcc coverage`
- `05838b8e0a` `aarch64: chain ADCS xzr into lazy B.cond`
- `c23d399354` `aarch64: chain ADCS rd into lazy B.cond`
- `996e400881` `aarch64: chain SBCS rd into lazy B.cond`

What is now in place there:

- bounded-gap `CMP/SUBS xzr -> B.cond`
- bounded-gap `CMN/ADDS xzr -> B.cond`
- same whitelist and same `A64_CMP_PENDING_GAP_MAX == 8` bound

Current scope limits that matter for follow-up prioritization:

- add-side direct branch support now covers:
  - `EQ/NE/CS/CC/HI/LS/GE/LT/GT/LE`
  - `MI/PL/VS/VC`
- compare-like carry-add producer support now covers:
  - `ADCS xzr -> B.cond`
- materialized carry-producer support now covers:
  - `ADCS rd -> B.cond`
  - `SBCS rd -> B.cond`
  - current rollout is intentionally limited to non-adjacent gap cases
- adjacent precedence currently stays on the stable direct `age=1` path; exact
  `rewind` trace parity is still deferred

Because of that progress, the highest-value candidate list now shifts.

## Candidate Matrix

| Priority | Candidate path | Benefit | Risk | Continuity | Notes |
|---|---|---|---|---|---|
| P1 | 32-bit `ADCS/SBCS rd -> B.cond` coverage and remaining condition fill-in | Medium | Medium | High | Lowest-risk continuation of the just-landed materialized carry-producer branch line |
| P2 | Bounded-gap `CSEL/CCMP/CS*` consumers off compare-like producers | Medium-High | High | Medium-High | Best structural reuse of the new bounded lifetime beyond plain branches |
| P3 | `ANDS/TST -> B.cond/CSEL/CCMP` | Medium | Medium | Medium | Logic-flag line is still attractive and fairly clean on x86 |
| P4 | Explicit adjacent rewind bookkeeping parity | Low-Medium | High | Medium | Useful for trace/model parity, but not the best immediate performance ROI |
| P5 | `CMN/CMP -> ADCS/SBCS` seeded semi-direct path | Medium | High | Medium | Still not a true live-`CF` direct path; keep it separated from the mainline |

## Recommended Structural Direction

The structural mainline should still be:

- `lazy compare design` phase 2

Reason:

- many obvious adjacent compare-consumer fast paths are already done
- continuing only with pairwise direct helpers will run into combination growth
- lazy compare attacks the root problem by letting compare-like producer value
  survive across bounded gap-safe instructions

## User-Selected Kickoff: "Route 3"

The earlier "route 3" kickoff effectively turned into the first `lazy compare`
branch rollout rather than a separate `ADDS/SUBS/ADCS/SBCS -> B.cond` helper
line.

### What remains in that route after `996e400881`

- 32-bit materialized carry producers:
  - `ADCS/SBCS rd -> B.cond`
- any remaining condition / adjacency scope decisions for the materialized line

### Why it is not a substitute for lazy compare

- the current rollout solved the first bounded compare-like branch slice
- it still does not cover broader non-branch consumers
- it still leaves adjacent rewind bookkeeping as a separate correctness /
  trace-model follow-up

So the healthy split is:

- **short-term feature slice**: finish add-side `B.cond` condition coverage,
  then evaluate `ADCS/SBCS -> B.cond`
- **structural mainline**: `lazy compare design` phase 2

## Benefit / Risk Comparison: Lazy Compare vs. More Pairwise Direct Paths

### More pairwise direct paths

**Pros**

- fast to land
- narrow blast radius
- easy to validate with focused asm and `out_asm`

**Cons**

- producer x consumer x form x width combinations grow quickly
- wins stay restricted to a tight adjacent whitelist
- each new path tends to need its own dedicated oracle

### Lazy compare design

**Pros**

- addresses the underlying producer-lifetime limitation
- can unlock multiple consumers off one bounded lazy compare record
- scales better than adding one helper per producer/consumer pair

**Cons**

- invalidation rules become much harder
- raw/split/canonical flags interactions need explicit invariants
- bugs are subtler and require stronger debug instrumentation

## Current Recommendation

1. Commit and document the current `ADCS/SBCS` closure
2. If continuing immediate feature work, start with:
   - 32-bit `ADCS/SBCS rd -> B.cond`
3. After that, evaluate:
   - bounded-gap `CSEL/CCMP/CS*`
4. In parallel, keep the structural mainline on:
   - bounded lazy compare reuse for non-branch consumers
