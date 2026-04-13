# Compare-like Producer Sidecar Shrink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink compare-like producer `pending_cc` sidecar usage so plain downstream `B.cond` / `CSEL/CS*` / `ADC/SBC` / `CCMP/FCCMP` cases rely on current `RAW/SPLIT` main representation by default, while keeping adjacent specialized paths intact.

**Architecture:** Limit this first stage to compare-like `CMP/CMN` and `SUBS/ADDS rd==xzr` producer sites in `translate-a64.c`. Keep old `pending_cc` record/consume only for clearly adjacent specialized shapes such as adjacent `ADCS/SBCS` and existing adjacent rechain-positive combinations. For plain downstream consumers that already read main representation, stop recording old producer sidecars unless the adjacent specialized path actually needs them.

**Tech Stack:** QEMU AArch64 TCG frontend, x86 TCG backend, AArch64 focused assembly/codegen tests, SPEC CPU2017 smoke tests, Git

---

## File Map

| File | Responsibility |
|------|------|
| `target/arm/tcg/translate-a64.c` | Narrow compare-like producer sidecar recording to adjacent specialized paths and preserve durable main-flags publish for plain downstream cases |
| `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh` | Assert plain gap branch shapes no longer require old producer-side `pending_cc` use |
| `tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh` | Assert plain gap `CSEL/CS*` shapes no longer depend on old producer-side `pending_cc` |
| `tests/tcg/aarch64/check-adc-sbc-host-direct.sh` | Keep plain gap `ADC/SBC` oracle aligned with sidecar-shrink semantics |
| `tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh` | Assert plain `CCMP` gap cases do not depend on old producer-side pending pairing |
| `tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh` | Assert plain `FCCMP` gap cases do not depend on old producer-side pending pairing |
| `progress.md` | Record the first producer-side sidecar shrink milestone and verification result |

## Task 1: Add Red Focused Checks for Producer-Side Sidecar Shrink

**Files:**
- Modify: `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh`
- Modify: `tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh`
- Modify: `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- Modify: `tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh`
- Modify: `tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh`

- [ ] **Step 1: Update plain gap branch expectations**

In `tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh`, tighten the oracle for
plain compare-like producer cases so success is no longer “producer recorded
pending”. Make the positive cases accept:

- no producer-side record
- or producer-side record with downstream `assert_no_use`

Preserve the old strict assertions for adjacent specialized path cases.

- [ ] **Step 2: Update plain gap `CSEL/CS*` expectations**

In `tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh`, make the same semantic
shift:

- plain gap positives must not require `CSEL-pending` consume from the old
  producer
- adjacent chain-positive / reseed-positive shapes keep their old pending
  assertions

- [ ] **Step 3: Keep `ADC/SBC` focused expectations aligned**

In `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`, verify that the plain gap
`CMN -> ADC` and `CMP -> SBC` positives continue to assert:

- no old producer consume
- consumer reads current main representation

Do not broaden this checker into adjacent `ADCS/SBCS` behavior.

- [ ] **Step 4: Update plain `CCMP/FCCMP` gap expectations**

In `tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh` and
`tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh`, make the plain gap
positives reflect the new producer-side rule:

- old producer-side pending record is optional
- if it exists, downstream plain `CCMP/FCCMP` must still not consume it

- [ ] **Step 5: Run the focused checks and confirm at least one now fails on current main**

Run:

```bash
bash tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct

bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct

bash tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct

bash tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-ccmp-gap-host-direct

bash tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-fccmp-gap-host-direct
```

Expected:

- at least one focused checker fails because compare-like producers still record
  sidecar in a plain downstream case that no longer needs it

- [ ] **Step 6: Commit the red-test oracle changes**

```bash
git add tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
        tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
        tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
        tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh \
        tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh
git commit -m "tests/aarch64: tighten compare-like sidecar shrink oracles"
```

## Task 2: Shrink Compare-like Producer Recording in `translate-a64.c`

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: Identify the compare-like producer record sites**

In `target/arm/tcg/translate-a64.c`, isolate the `CMP/CMN` and `SUBS/ADDS rd==xzr`
record sites in:

- `do_addsub_imm`
- `do_addsub_ext`
- `do_addsub_reg`

Do not touch materialized `ADDS/SUBS rd` or promoted `CCMP/CCMN` yet.

- [ ] **Step 2: Split “plain downstream main-state publish” from “adjacent sidecar record”**

Refactor the boolean routing so these concepts are no longer bundled:

- plain downstream consumer families that already read main representation
- adjacent specialized paths that still need `pending_cc`

The implementation should make it impossible for a plain downstream case to
implicitly drag old sidecar record along just because the producer family
historically shared one boolean bundle.

- [ ] **Step 3: Keep durable main-flags publish for plain downstream cases**

When a compare-like producer feeds:

- plain gap `B.cond`
- plain gap `CSEL/CS*`
- plain gap `ADC/SBC`
- plain `CCMP/FCCMP`

continue to publish current `RAW/SPLIT` main representation as needed. Do not
let sidecar shrink accidentally remove main-state availability.

- [ ] **Step 4: Restrict `pending_cc` record to adjacent specialized shapes**

Only keep producer-side `pending_cc` record where the downstream shape still
needs it:

- adjacent `CMN/CMP -> ADCS/SBCS`
- adjacent reseed / rechain-positive paths already covered by focused evidence

Plain downstream cases should no longer record old producer sidecar by default.

- [ ] **Step 5: Rebuild after the routing change**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
```

Expected:

- build succeeds

- [ ] **Step 6: Commit the producer-side shrink**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: shrink compare-like producer sidecars"
```

## Task 3: Turn the Focused Sidecar-Shrink Checks Green

**Files:**
- Modify: `target/arm/tcg/translate-a64.c` if any final boundary fix is needed
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/*`

- [ ] **Step 1: Run the five focused checkers**

Run:

```bash
bash tests/tcg/aarch64/check-cmp-bcond-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-gap-host-direct

bash tests/tcg/aarch64/check-cmp-csel-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-gap-host-direct

bash tests/tcg/aarch64/check-adc-sbc-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct

bash tests/tcg/aarch64/check-cmp-ccmp-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-ccmp-gap-host-direct

bash tests/tcg/aarch64/check-cmp-fccmp-gap-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-fccmp-gap-host-direct
```

Expected:

- all five pass

- [ ] **Step 2: Check neighboring chain-focused regressions**

Run:

```bash
bash tests/tcg/aarch64/check-cmp-ccmp-bcond-chain-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-ccmp-bcond-chain-host-direct

bash tests/tcg/aarch64/check-cmp-csel-bcond-chain-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-bcond-chain-host-direct

bash tests/tcg/aarch64/check-cmp-csel-ccmp-chain-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-csel-ccmp-chain-host-direct

bash tests/tcg/aarch64/check-cmp-ccmp-csel-ccmp-chain-host-direct.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-ccmp-csel-ccmp-chain-host-direct
```

Expected:

- adjacent rechain / specialized path checks stay green

- [ ] **Step 3: If any adjacent path regresses, make the smallest boundary fix**

Only adjust the producer-side predicate split. Do not widen the scope into
materialized `ADDS/SUBS rd` or promoted `CCMP/CCMN`.

- [ ] **Step 4: Re-run the same focused and chain checks**

Expected:

- all previously green checks remain green

- [ ] **Step 5: Commit the green boundary fix if one was needed**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: fix adjacent sidecar shrink boundaries"
```

## Task 4: Run Shared Regressions and Smoke Tests

**Files:**
- Test: `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- Test: `/home/wangruoyu/cpuspec2017/result/CPU2017.*`

- [ ] **Step 1: Run shared architectural/codegen regressions**

Run:

```bash
bash tests/tcg/aarch64/check-nzcv-status4-raw-ccop-specialization.sh \
  build-aarch64-linux-user/qemu-aarch64 \
  build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- pass

- [ ] **Step 2: Run SPEC CPU2017 smoke**

Run:

```bash
cd /home/wangruoyu/cpuspec2017
./bin/runcpu --config qemu_aarch64_tcg.cfg --action run --tune base \
  --size test --iterations 1 --nobuild \
  502.gcc_r 505.mcf_r 531.deepsjeng_r 541.leela_r 557.xz_r
```

Expected:

- `502.gcc_r`, `505.mcf_r`, `531.deepsjeng_r`, `541.leela_r`, `557.xz_r`
  all report `Success`

- [ ] **Step 3: Record the new result bundle path**

Capture the resulting log path under `/home/wangruoyu/cpuspec2017/result/`
and use it in the progress update.

- [ ] **Step 4: Commit nothing in this task**

This task is verification-only.

## Task 5: Update Progress and Knowledge-Base Notes

**Files:**
- Modify: `progress.md`
- Update via MCP: `01-项目总览/当前状态总览.md`
- Update via MCP: `03-优化专题/NZCV direct paths 与 producer chaining 当前状态.md`
- Update via MCP: `06-时间线/NZCV 优化主时间线.md`
- Create via MCP: `05-决策与方案演进/为什么 compare-like producer sidecar 要继续收缩.md`

- [ ] **Step 1: Add a new progress section**

In `progress.md`, document:

- what plain downstream shapes stopped depending on producer-side sidecar record
- what adjacent specialized paths were intentionally kept
- which focused checks were updated
- the exact SPEC result bundle and log path

- [ ] **Step 2: Update the current-state note**

Append a concise milestone note explaining that plain consumer migration is
effectively complete and the active next step became producer-side sidecar
shrink.

- [ ] **Step 3: Update the topic and timeline notes**

Record that sidecar is no longer the default semantic carrier for compare-like
plain downstream cases, only a narrow acceleration layer.

- [ ] **Step 4: Add a decision note**

Write a short decision note capturing:

- why this step came after plain `ADC/SBC`
- why the first stage targets `CMP/CMN`
- why “shrink” was chosen over “delete all sidecar”

- [ ] **Step 5: Commit the local progress update only**

```bash
git add progress.md
git commit -m "docs: record compare-like sidecar shrink milestone"
```
