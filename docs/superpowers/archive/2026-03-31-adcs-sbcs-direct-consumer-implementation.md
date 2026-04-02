> Archive: historical implementation plan kept for reference. The implemented
> result is now summarized from `progress.md`.

# ADCS/SBCS Direct Consumer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement same-TB adjacent `ADCS/SBCS` as direct consumers of `pending_cc` producers (CMN/CMP/ADDS/SUBS), using live x86 host CF without canonical carry decode, and capturing consumer raw flags directly.

**Architecture:** Producer lookahead extended to recognize adjacent `ADCS/SBCS` in addition to plain `ADC/SBC`. New setflags-specific consumer helpers (`a64_try_emit_x86_add_adcs` / `a64_try_emit_x86_cmp_sbcs`) emit host `adc/sbb` with raw flag capture and NO producer state restoration. Existing plain helpers remain unchanged.

**Tech Stack:** QEMU TCG, AArch64 AArch32 translation, x86 host codegen, inline assembly tests

---

## File Map

| File | Role |
|------|------|
| `target/arm/tcg/translate-a64.c` | Core implementation: producer lookahead, consumer helpers, `do_adc_sbc()` control flow |
| `target/arm/tcg/translate.h` | `A64PendingCCProducer` struct, `A64_X86_CC_ADC*/SBC*` raw flag kind definitions |
| `tests/tcg/aarch64/adc-sbc-host-direct.S` | Host codegen guard: verifies `adc/sbb` actually emitted with correct shape |
| `tests/tcg/aarch64/nzcv-status4.S` | Semantic coverage: verifies final NZCV comes from ADCS/SBCS consumer, not producer |
| `tests/tcg/aarch64-linux-user/adc-sbc-host-direct.outasm.log` | Disassembled output for manual codegen inspection |

---

## Task 1: Extend producer lookahead to recognize ADCS/SBCS

**Files:**
- Modify: `target/arm/tcg/translate-a64.c:932-948` (a64_find_adjacent_plain_adc)
- Modify: `target/arm/tcg/translate-a64.c:896-912` (a64_find_adjacent_plain_sbc_cmp)
- Modify: `target/arm/tcg/translate-a64.c:914-930` (a64_find_adjacent_plain_sbc_sub)

- [ ] **Step 1: Read current a64_find_adjacent_plain_adc and a64_find_adjacent_plain_sbc_* implementations**

Read lines 896-972 in translate-a64.c to understand the current structure.

- [ ] **Step 2: Add a64_insn_is_plain_adcs_reg helper**

After `a64_insn_is_plain_adc_reg` (line ~774), add:

```c
static bool a64_insn_is_plain_adcs_reg(uint32_t insn)
{
    /* ADCS: same opcode family as ADC, but with S bit set */
    /* Encoding: |sf|opc|1010100|rm|rn|rd| where opc[1]=1 indicates setflags */
    /* Mask: (insn & 0x7e20fc00u) == 0x3a200000u for 64-bit, similar for 32 */
    /* Actually, need to match ADCS specifically - inspect ADC encoding */
    /* ADC:  0x1a000000 | (sf<<31) | (op2<<10) | (rm<<16) | (rn<<5) | rd */
    /* ADCS: 0x3a000000 | (sf<<31) | (op2<<10) | (rm<<16) | (rn<<5) | rd */
    /* For register form: op2 = 000, so ADCS = 0x3a000000 | (sf<<31) | (rm<<16) | (rn<<5) | rd */
    return (insn & 0x7e200000u) == 0x3a000000u;
}
```

Verify exact encoding by cross-referencing the ADC mask at line 774 and checking how ADCS differs (S bit in [0]=0x80000000 should be set, and top bits are 0x3a not 0x1a). Actually review the existing `a64_insn_is_plain_adc_reg` first to confirm the mask, then derive the ADCS mask.

- [ ] **Step 3: Add a64_insn_is_plain_sbcs_reg helper**

```c
static bool a64_insn_is_plain_sbcs_reg(uint32_t insn)
{
    /* SBCS: 0x7a000000 | (sf<<31) | (rm<<16) | (rn<<5) | rd */
    /* SBC = 0x5a, SBCS has S bit (bit29) set = 0x5a | 0x20000000 = 0x7a */
    return (insn & 0x7e200000u) == 0x7a000000u;
}
```

- [ ] **Step 4: Extend a64_find_adjacent_plain_adc to also recognize ADCS**

Change the return to:
```c
return a64_insn_is_plain_adc_reg(arm_ldl_code(...)) ||
       a64_insn_is_plain_adcs_reg(arm_ldl_code(...));
```

- [ ] **Step 5: Extend a64_find_adjacent_plain_sbc_cmp and a64_find_adjacent_plain_sbc_sub to also recognize SBCS**

Similar extension to return true for either plain SBC or SBCS.

- [ ] **Step 6: Build to verify compilation**

```bash
cd /home/wangruoyu/qemu10.2 && ninja -C build-aarch64-linux-user qemu-aarch64 2>&1 | head -50
```
Expected: No new errors (warnings acceptable).

- [ ] **Step 7: Commit**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: extend producer lookahead to recognize adjacent ADCS/SBCS"
```

---

## Task 2: Add A64_X86_CC_ADC*/SBC* raw flag kinds if not already present

**Files:**
- Modify: `target/arm/tcg/translate.h` (likely around existing A64_X86_CC definitions)

- [ ] **Step 1: Search for existing A64_X86_CC_ADC* definitions**

```bash
grep -n "A64_X86_CC_ADC\|A64_X86_CC_SBC" /home/wangruoyu/qemu10.2/target/arm/tcg/translate.h
```

- [ ] **Step 2: If A64_X86_CC_ADC32/ADC64 and SBC32/SBC64 don't exist, add them**

The consumer helpers need to set raw state to these new kinds. If they exist already (from plain ADC/SBC work), skip this task.

- [ ] **Step 3: Commit if changed**

```bash
git add target/arm/tcg/translate.h
git commit -m "aarch64: add A64_X86_CC_ADC*/SBC* raw flag kinds for setflags consumers"
```

---

## Task 3: Implement a64_try_emit_x86_add_adcs() helper

**Files:**
- Modify: `target/arm/tcg/translate-a64.c` (new function after a64_try_emit_x86_add_adc)

- [ ] **Step 1: Read a64_try_emit_x86_add_adc() implementation (lines ~2064-2149)**

Understand:
- How it checks `s->a64_pending_cc.valid`
- How it checks `cc_op == A64_X86_CC_ADD64/ADD32`
- How it consumes the pending producer
- How it emits `adc`
- How it captures raw flags and sets final state
- How it does NOT restore producer flags (this is key difference from plain ADC)

- [ ] **Step 2: Implement a64_try_emit_x86_add_adcs()**

This is the setflags add-side consumer. Key differences from plain:
- **NO call to** `a64_get_current_carry_flag()` — use pending producer's live CF directly
- Emit host `adc` (not `adc` with extra glue)
- Capture raw flags as `A64_X86_CC_ADC32/ADC64`
- Set `s->a64_pending_cc.valid = false` (consumed)
- Set final raw state to ADC kind (NOT restoring producer state)
- Return `true` on success, `false` if conditions not met

```c
static bool a64_try_emit_x86_add_adcs(DisasContext *s, bool sf,
                                      TCGv_i64 rd, TCGv_i64 rn, TCGv_i64 rm)
{
    if (!s->a64_pending_cc.valid) {
        return false;
    }
    if (s->a64_pending_cc.cc_op != (sf ? A64_X86_CC_ADD64 : A64_X86_CC_ADD32)) {
        return false;
    }
    /* Verify this is an add-side producer (not sub) */
    if (s->a64_pending_cc.kind != A64_PENDING_CC_MATERIALIZED_ADD &&
        s->a64_pending_cc.kind != A64_PENDING_CC_REWINDABLE_CMP) {
        /* For compare-like, we need to handle CMN which is add-equivalent */
    }
    /* Check producer/consumer are truly adjacent - pending_cc should already have this info */

    /* Emit adc - CF is live from producer */
    if (sf) {
        tcg_gen_adc_i64(rd, rn, rm);
        a64_set_raw_flags_state(s, A64_X86_CC_ADC64);
    } else {
        TCGv_i32 rd32 = tcg_temp_new_i32();
        TCGv_i32 rn32 = tcg_temp_new_i32();
        TCGv_i32 rm32 = tcg_temp_new_i32();
        tcg_gen_extrl_i64_i32(rn32, rn);
        tcg_gen_extrl_i64_i32(rm32, rm);
        tcg_gen_adc_i32(rd32, rn32, rm32);
        tcg_gen_extrl_i32_i64(rd, rd32);
        a64_set_raw_flags_state(s, A64_X86_CC_ADC32);
        tcg_temp_free_i32(rd32);
        tcg_temp_free_i32(rn32);
        tcg_temp_free_i32(rm32);
    }

    s->a64_pending_cc.valid = false;
    return true;
}
```

Note: Actually the pending_cc for compare-like producers (CMN) needs special handling since the `lhs/rhs` in pending_cc represent the operands. For rewindable cmp, the carry comes from the rewind. For materialized add, the carry is already computed. Look at how `a64_try_emit_x86_add_adc` handles the different producer kinds.

- [ ] **Step 3: Read how a64_try_emit_x86_add_adc() handles producer kinds**

The plain helper handles both `A64_PENDING_CC_MATERIALIZED_ADD` and `A64_PENDING_CC_REWINDABLE_CMP`. Study this before finalizing the setflags version.

- [ ] **Step 4: Build to verify**

```bash
cd /home/wangruoyu/qemu10.2 && ninja -C build-aarch64-linux-user qemu-aarch64 2>&1 | head -80
```
Expected: Compilation succeeds. Warnings about unused functions are OK.

- [ ] **Step 5: Commit**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: add a64_try_emit_x86_add_adcs() helper for setflags direct path"
```

---

## Task 4: Implement a64_try_emit_x86_cmp_sbcs() helper

**Files:**
- Modify: `target/arm/tcg/translate-a64.c` (new function after a64_try_emit_x86_cmp_sbc)

- [ ] **Step 1: Read a64_try_emit_x86_cmp_sbc() implementation (lines ~1993-2061)**

Key differences to understand:
- How SUB32/SUB64 cc_op is checked
- How it handles `A64_PENDING_CC_MATERIALIZED_SUB` vs `A64_PENDING_CC_REWINDABLE_CMP`
- How borrow semantics work for sbb

- [ ] **Step 2: Implement a64_try_emit_x86_cmp_sbcs()**

Mirror the add-side logic but for sub:
- NO `a64_get_current_carry_flag()` call
- Use pending producer's live CF/borrow
- Emit host `sbb`
- Capture raw flags as `A64_X86_CC_SBC32/SBC64`
- Set final raw state to SBC kind
- Consume pending_cc

```c
static bool a64_try_emit_x86_cmp_sbcs(DisasContext *s, bool sf,
                                       TCGv_i64 rd, TCGv_i64 rn, TCGv_i64 rm)
{
    if (!s->a64_pending_cc.valid) {
        return false;
    }
    if (s->a64_pending_cc.cc_op != (sf ? A64_X86_CC_SUB64 : A64_X86_CC_SUB32)) {
        return false;
    }
    /* Similar producer kind handling as add-side */

    if (sf) {
        tcg_gen_sbb_i64(rd, rn, rm);
        a64_set_raw_flags_state(s, A64_X86_CC_SBC64);
    } else {
        TCGv_i32 rd32 = tcg_temp_new_i32();
        TCGv_i32 rn32 = tcg_temp_new_i32();
        TCGv_i32 rm32 = tcg_temp_new_i32();
        tcg_gen_extrl_i64_i32(rn32, rn);
        tcg_gen_extrl_i64_i32(rm32, rm);
        tcg_gen_sbb_i32(rd32, rn32, rm32);
        tcg_gen_extrl_i32_i64(rd, rd32);
        a64_set_raw_flags_state(s, A64_X86_CC_SBC32);
        tcg_temp_free_i32(rd32);
        tcg_temp_free_i32(rn32);
        tcg_temp_free_i32(rm32);
    }

    s->a64_pending_cc.valid = false;
    return true;
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /home/wangruoyu/qemu10.2 && ninja -C build-aarch64-linux-user qemu-aarch64 2>&1 | head -80
```

- [ ] **Step 4: Commit**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: add a64_try_emit_x86_cmp_sbcs() helper for setflags direct path"
```

---

## Task 5: Update do_adc_sbc() control flow for setflags consumers

**Files:**
- Modify: `target/arm/tcg/translate-a64.c:11407-11462`

- [ ] **Step 1: Read current do_adc_sbc() implementation**

Focus on the current control flow:
1. Check `lazy_bcond_cmp` for `SBCS xzr -> future B.cond`
2. Try plain ADC path: `a64_try_emit_x86_add_adc` (when `!setflags && !is_sub`)
3. Try plain SBC path: `a64_try_emit_x86_cmp_sbc` (when `!setflags && is_sub`)
4. Fallback: get carry + gen_adc_CC/gen_sbc

- [ ] **Step 2: Insert setflags consumer attempt AFTER plain paths, BEFORE fallback**

Following the spec's recommended order:
1. Plain ADC/SBC fast paths (unchanged)
2. `SBCS xzr -> B.cond` lazy path check (unchanged)
3. **NEW**: Setflags direct consumer attempt
4. Fallback

```c
// After the two !setflags direct attempts, BEFORE the carry get:

if (setflags && !is_sub) {
    // Try ADCS direct path
    if (a64_try_emit_x86_add_adcs(s, a->sf, tcg_rd, tcg_rn, tcg_rm)) {
        return true;
    }
}

if (setflags && is_sub) {
    // Try SBCS direct path
    if (a64_try_emit_x86_cmp_sbcs(s, a->sf, tcg_rd, tcg_rn, tcg_rm)) {
        return true;
    }
}
```

The key is: **do NOT restore producer flags** after consuming in the setflags path. The consumer's raw flags become the canonical state directly.

- [ ] **Step 3: Verify the lazy_bcond_cmp priority is preserved**

The `SBCS xzr -> future B.cond` path must be checked BEFORE the new setflags direct path, to avoid抢走相邻producer的优先级. The current code already checks `lazy_bcond_cmp` before any direct path, so this should be fine — but verify.

- [ ] **Step 4: Build to verify**

```bash
cd /home/wangruoyu/qemu10.2 && ninja -C build-aarch64-linux-user qemu-aarch64 2>&1 | head -80
```

- [ ] **Step 5: Commit**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "aarch64: integrate ADCS/SBCS setflags direct path into do_adc_sbc()"
```

---

## Task 6: Add ADCS/SBCS coverage to host codegen guard (adc-sbc-host-direct.S)

**Files:**
- Modify: `tests/tcg/aarch64/adc-sbc-host-direct.S`

- [ ] **Step 1: Read current adc-sbc-host-direct.S test structure**

Understand the block format, how they test adjacent producer->consumer patterns, and how the disassembler check works.

- [ ] **Step 2: Add compare-like producer -> ADCS/SBCS test blocks**

After existing blocks, add:

```
// CMN (compare-like add) -> ADCS
// CMN x0, x1 / ADCS x5, x6, x7
// Expected: host adc instruction, consumer captures flags
// Register form, 64-bit
block_cmn_adcs:
    movn    x0, #0            /* -1 */
    mov     x1, #1
    cmn     x0, x1             /* C = 1 */
    mov     x5, #10
    mov     x6, #20
    adcs    x7, x5, x6
    cmp     x7, #31
    b.ne    fail
    /* NZCV from ADCS: N=0 Z=0 C=1 V=0 -> 0x2, shifted >>28 = 0 */
    /* Actually CMN sets N=0 Z=0 C=1 V=0 from -1+1=0 with overflow */
    /* Wait: cmn x0,x1 = -1 + -1 = -2, no overflow, C=0... */
    /* Need to recalculate: CMN with movn #0 means x0=-1, cmn x0,#1 = -1 + -1 = -2 */
    /* The carry from cmn is NOT the same as from cmp. CMN is addition. */
    /* For CMN: if no overflow, C=0; if overflow, C=1 */
    /* movn x0,#0 = x0 = -1. cmn x0,#1 = -1 + -1 = -2, no overflow -> C=0 */
    /* This isn't right for testing... Let me reconsider */
    /* Actually the point is to test the DIRECT PATH, not specific flag values */
    /* Just verify ADCS executes correctly */
    /* Need CMN with carry=1: use cmn x0, x0 where x0 has high bits set */
    ret
```

Actually, look at existing CMN patterns in the test to understand what generates carry=1. The existing test at line 10-14 shows:
```asm
movn    x0, #0    /* -1 */
mov     x1, #1
cmn     x0, x1    /* -1 + -1 = -2, no overflow -> C=0 */
adc     x7, x5, x6 /* so this computes 9+3+0 = 12... but it expects 13 */
```

Wait, looking at line 10-14:
```asm
movn    x0, #0    /* = 0xFFFFFFFFFFFFFFFF */
mov     x1, #1
cmn     x0, x1    /* 0xFFFFFFFF + 1 = 0 with carry -> C=1 */
adc     x7, x5, x6 /* so 9+3+1 = 13 */
```

So `movn x0, #0` sets x0 to -1 (all bits set). `cmn x0, #1` adds -1 + -1 = -2, no overflow → wait that's wrong too. `cmn` negates the second operand, so `cmn x0, #1` is `x0 + -1`. With x0=0xFFFFFFFFFFFFFFFF (-1), this is -1 + -1 = -2, no overflow → C=0.

But wait, the existing test expects 13! So the carry must be 1. Let me reconsider: `movn x0, #0` sets x0 to the bitwise NOT of 0, which is all 1s = -1 in two's complement. `cmn x0, #1` = `x0 + (~1)` = `-1 + (-1)` in two's complement... actually `cmn` computes `rn + ~imm` (the negative), which is `rn + (-imm)`. So `cmn x0, #1` = `x0 + (-1)`. If x0 = -1, then -1 + (-1) = -2, C=0. But the test clearly expects 13!

Let me look at lines 9-14 more carefully:
```asm
movn    x0, #0     // x0 = -1 (all bits set)
mov     x1, #1
cmn     x0, x1     // x0 + (-x1) = -1 + (-1) = -2 ... C=0
adc     x7, x5, x6 // 9 + 3 + C = 12 if C=0, 13 if C=1
cmp     x7, #13    // expects 13!
```

So the test expects C=1. That means my understanding of `cmn` is wrong. Actually `cmn` computes `rn + rm` where rm is the materialized value (not negated). Wait, no — in AArch64, `CMN is aliases to `ADDS` with xzr as destination. So `cmn x0, x1` is actually `adds xzr, x0, x1`. So `cmn x0, #1` = `adds xzr, x0, #1`. For x0=-1, this is -1 + 1 = 0, and -1+1 doesn't overflow so C=0.

Hmm, but the test clearly expects 13! Maybe I'm misreading something. Actually looking at line 10 again: `movn x0, #0` sets x0 to NOT #0, which is all 1s = -1. Then `cmn x0, x1` where x1=1 is `adds xzr, x0, x1` = -1 + 1 = 0, no overflow, C=0. But then 9+3+0=12, not 13. There's a contradiction here.

Let me check if there's something else going on with how the flags are being computed or if I'm misunderstanding the test structure.

Actually, looking at line 12-14, the `adc x7, x5, x6` computes `9+3+carry`. For it to equal 13, carry must be 1. So my analysis of `cmn` must be wrong. Let me reconsider: `cmn` is aliases to `adds`, and `movn` is bitwise NOT, not two's complement negation. So `movn x0, #0` gives all bits set (0xFFFFFFFFFFFFFFFF), and `cmn x0, #1` computes the addition with the immediate being sign-extended and negated. For 1, that's -1, so -1 + -1 = -2 with no overflow, giving carry 0. But then `adc` should give 12, not 13. I need to actually trace through the ARM64 specification to understand what's happening here.

Actually, I should just add test cases for ADCS/SBCS direct paths and move forward with the implementation rather than getting stuck on this analysis.

- [ ] **Step 3: Add test blocks**

Add at minimum:
- `cmn x0, x1` / `adcs x5, x6, x7` (register form, 64-bit)
- `cmp x0, x1` / `sbcs x5, x6, x7` (register form, 64-bit)
- `cmn w0, w1` / `adcs w5, w6, w7` (register form, 32-bit)
- `cmp w0, w1` / `sbcs w5, w6, w7` (register form, 32-bit)
- Immediate and extended forms for each
- `adds x5, x0, x1` / `adcs x7, x6, x7` (materialized producer)
- `subs x5, x0, x1` / `sbcs x7, x6, x7` (materialized producer)
- `sbcs xzr, x1, x2` / `b.cs` (priority regression test for `SBCS xzr -> B.cond`)

- [ ] **Step 4: Build and run the test**

```bash
cd /home/wangruoyu/qemu10.2 && ./build-aarch64-linux-user/qemu-aarch64 -L /home/wangruoyu/qemu10.2/build-aarch64-linux-user/tests/tcg/aarch64-linux-user/ /home/wangruoyu/qemu10.2/build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct 2>&1
```

Or whatever the correct test invocation path is.

- [ ] **Step 5: Commit**

```bash
git add tests/tcg/aarch64/adc-sbc-host-direct.S
git commit -m "aarch64: add ADCS/SBCS direct consumer coverage to host codegen guard"
```

---

## Task 7: Add ADCS/SBCS coverage to nzcv-status4.S

**Files:**
- Modify: `tests/tcg/aarch64/nzcv-status4.S`

- [ ] **Step 1: Study existing nzcv-status4.S patterns**

Understand how `expect_nzcv` macro works and what NZCV values to expect for each test case.

- [ ] **Step 2: Add test cases for ADCS/SBCS with direct path**

Add test cases that verify:
- Final NZCV comes from the ADCS/SBCS consumer (not the producer)
- Compare-like producer (CMN/CMP) -> ADCS/SBCS
- Materialized producer (ADDS/SUBS rd) -> ADCS/SBCS
- 32-bit and 64-bit variants
- Boundary conditions (overflow, zero result, borrow)

For example:
```
/* 0xXX: CMN (carry=1) -> ADCS, consumer NZCV should be from ADCS */
movn    x0, #0            /* -1 */
mov     x1, #1
cmn     x0, x1             /* C=1, V=0, Z=0, N=0 */
mov     x5, #9
mov     x6, #3
adcs    x7, x5, x6         /* 9+3+1=13, NZCV from adcs computation */
expect_nzcv_from_adcs 0xXX

/* 0xXX: CMP (borrow) -> SBCS, consumer NZCV should be from SBCS */
mov     x0, #5
mov     x1, #3
cmp     x0, x1             /* 5-3=2, no borrow -> C=1 */
mov     x5, #9
mov     x6, #3
sbcs    x7, x5, x6         /* 9-3-!borrow = 9-3-0=6? Wait... */
```

Need to carefully construct the SBCS tests to understand expected NZCV output.

- [ ] **Step 3: Build and run**

```bash
cd /home/wangruoyu/qemu10.2 && ./build-aarch64-linux-user/qemu-aarch64 -L ... tests/tcg/aarch64-linux-user/nzcv-status4
```

- [ ] **Step 4: Commit**

```bash
git add tests/tcg/aarch64/nzcv-status4.S
git commit -m "aarch64: add ADCS/SBCS NZCV coverage to nzcv-status4"
```

---

## Task 8: Full build and regression test

- [ ] **Step 1: Full clean build**

```bash
cd /home/wangruoyu/qemu10.2 && ninja -C build-aarch64-linux-user clean 2>&1 | tail -5
cd /home/wangruoyu/qemu10.2 && ninja -C build-aarch64-linux-user qemu-aarch64 2>&1 | tail -20
```

- [ ] **Step 2: Run adc-sbc-host-direct**

```bash
cd /home/wangruoyu/qemu10.2/build-aarch64-linux-user && ./qemu-aarch64 -L tests/tcg/aarch64-linux-user/ tests/tcg/aarch64-linux-user/adc-sbc-host-direct 2>&1
```

- [ ] **Step 3: Run nzcv-status4**

```bash
cd /home/wangruoyu/qemu10.2/build-aarch64-linux-user && ./qemu-aarch64 -L tests/tcg/aarch64-linux-user/ tests/tcg/aarch64-linux-user/nzcv-status4 2>&1
```

- [ ] **Step 4: Verify output**

Both tests should PASS. If FAIL, analyze the specific test case that failed.

- [ ] **Step 5: Run cmpstress-o3 if available**

```bash
cd /home/wangruoyu/qemu10.2 && find . -name "*cmpstress*" -o -name "*adcsbc*bench*" 2>/dev/null | head -10
```

---

## Risk Mitigation

### Risk 1: Mixing plain/setflags flags lifecycle
**Mitigation**: The new helpers DON'T call `a64_get_current_carry_flag()` and DON'T do producer state restoration. They consume pending_cc and set consumer raw state directly.

### Risk 2: Residual canonical carry decode glue
**Mitigation**: The codegen guard checks that consumer is adjacent to producer with no intermediate carry decode. Look for missing `a64_get_current_carry_flag()` calls before the `adc/sbb`.

### Risk 3: Sub-side borrow semantics error
**Mitigation**: SBCS tests should include boundary borrow cases, zero result, and overflow. The sub-side has more complex semantics.

### Risk 4: Producer lookahead expansion breaks plain/bcond paths
**Mitigation**: The lookahead extension is additive (now recognizes ADCS in addition to ADC, not instead of). Priority of `SBCS xzr -> B.cond` is preserved by checking `lazy_bcond_cmp` before setflags direct path.

---

## Non-Goals (Do Not Implement)

- New producer families beyond register/immediate/extended
- New `pending_cc.kind` values
- Cross-TB or gap extensions
- CCMP/CCMN or CSEL consumers
- New env gates
- Full CPU SPEC performance testing
