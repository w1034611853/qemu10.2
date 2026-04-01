# Direct-Path Candidate Matrix

## Goal

Provide a single prioritized view of the next direct-path candidates after the
current `ADCS/SBCS` closure, using three ranking axes:

- **Benefit**: likely performance upside or canonical-flags glue removed
- **Risk**: semantic and state-machine complexity
- **Continuity**: how naturally the work fits the current
  `pending_cc + raw/split flags + x86 host flags` framework

## Candidate Matrix

| Priority | Candidate path | Benefit | Risk | Continuity | Notes |
|---|---|---|---|---|---|
| P1 | `ADCS/SBCS -> ADC/SBC/ADCS/SBCS` | High | Medium | High | Best continuation of the current arithmetic carry/borrow line |
| P2 | `ADDS/SUBS/ADCS/SBCS -> B.cond` | Medium-High | Medium-High | Medium-High | Good value for "compute flags then branch" hot shapes |
| P3 | `ANDS/TST -> B.cond/CSEL/CCMP` | Medium | Medium | Medium | Logic-flag line is fairly clean on x86 |
| P4 | `CMN/CMP -> ADCS/SBCS` seeded semi-direct path | Medium | High | Medium | Not true live-`CF` direct path; better treated as specialized fallback optimization |
| P5 | `FCMP/FCMPE -> B.cond/FCSEL/FCCMP` | Medium | High | Low | Floating-point condition semantics are much riskier |
| P6 | `CSINC/CSINV/CSNEG/CSET/CSETM` family | Low-Medium | Low-Medium | Medium | Mostly an extension of already covered conditional-consumer work |

## Recommended Structural Direction

The structural mainline should still be:

- `lazy compare design` phase 2

Reason:

- many obvious adjacent compare-consumer fast paths are already done
- continuing only with pairwise direct helpers will run into combination growth
- lazy compare attacks the root problem by letting compare-like producer value
  survive across bounded gap-safe instructions

## User-Selected Kickoff: "Route 3"

If "route 3" refers to the third candidate discussed previously, that maps to:

- `ADDS/SUBS/ADCS/SBCS -> B.cond`

### Why this is a reasonable next focused route

- it stays in the integer arithmetic flags line
- it can reuse the test discipline from the current closure
- it avoids immediately jumping into floating-point or compare-like seeded paths

### Why it is not a substitute for lazy compare

- it is still another pairwise direct path
- it improves adjacent setflags-producer -> branch shapes
- it does not solve the wider producer lifetime problem

So the healthy split is:

- **short-term feature slice**: `ADDS/SUBS/ADCS/SBCS -> B.cond`
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
   - `ADDS/SUBS/ADCS/SBCS -> B.cond`
3. In parallel, prepare the next design step for:
   - `lazy compare design` phase 2
