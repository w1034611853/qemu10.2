# CMP to SBC Direct Consumer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a narrow x86 direct-consumer fast path for same-TB adjacent `CMP/SUBS -> plain SBC`, avoiding `raw_flags + cc_op` carry decode in the hot path.

**Architecture:** Reuse the existing A64 compare-pending metadata, but only for a new adjacent plain-`SBC` consumer. Add one fused i386 TCG opcode that emits `cmp; sbb` directly. Keep the scope narrow: same-TB, adjacent only, no gap handling, no cross-TB state changes, and no changes to `ADC` in this step.

**Tech Stack:** QEMU AArch64 TCG frontend, generic TCG core, i386 TCG backend, AArch64 TCG tests.

---

### Task 1: Add a failing codegen regression

**Files:**
- Modify: `tests/tcg/aarch64/adc-sbc-host-direct.S`
- Modify: `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

- [ ] **Step 1: Extend the assembly test with an adjacent `cmp -> sbc` case**
- [ ] **Step 2: Tighten the checker so it requires a direct `cmp; sbb` lowering for that case**
- [ ] **Step 3: Run `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adc-sbc-host-direct-codegen` and confirm it fails for the current implementation**

### Task 2: Add a fused x86 cmp+sbb opcode

**Files:**
- Modify: `tcg/i386/tcg-target-opc.h.inc`
- Modify: `tcg/i386/tcg-target-con-set.h`
- Modify: `tcg/tcg.c`
- Modify: `tcg/i386/tcg-target.c.inc`

- [ ] **Step 1: Define a narrow i386-only opcode for `cmp; sbb` with one tied output and four inputs**
- [ ] **Step 2: Register the opcode in TCG core dispatch**
- [ ] **Step 3: Implement x86 emission as `cmp` on pending compare operands followed by `sbb` on the destination**

### Task 3: Hook the opcode into the A64 frontend

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: Add a helper that consumes adjacent compare-pending state for plain `SBC` only**
- [ ] **Step 2: Restrict it to same-TB adjacent `CMP/SUBS` producers only**
- [ ] **Step 3: Fall back to the existing generic `gen_sbc()` path on any miss**

### Task 4: Verify behavior and codegen

**Files:**
- Test: `tests/tcg/aarch64/adc-sbc-host-direct.S`
- Test: `tests/tcg/aarch64/nzcv-status4.S`

- [ ] **Step 1: Re-run `run-adc-sbc-host-direct-codegen` and confirm it passes**
- [ ] **Step 2: Run `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **Step 3: Run `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **Step 4: Run `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`**
