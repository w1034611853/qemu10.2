/* SPDX-License-Identifier: GPL-2.0-or-later */

    .arch armv8.5-a
    .text
    .global _start

    .macro expect_branch cond, id
        mov     x20, #\id
        b.\cond 1f
        b       fail
1:
    .endm

    .macro expect_reg_imm reg, imm, id
        mov     x20, #\id
        cmp     \reg, #\imm
        b.eq    1f
        b       fail
1:
    .endm

    .macro expect_reg_reg lhs, rhs, id
        mov     x20, #\id
        cmp     \lhs, \rhs
        b.eq    1f
        b       fail
1:
    .endm

    .macro expect_nzcv imm, id
        mov     x20, #\id
        mrs     x0, nzcv
        lsr     x0, x0, #28
        cmp     x0, #\imm
        b.eq    1f
        b       fail
1:
    .endm

_start:
    /* 0x01: CMP (imm) -> B.eq */
    mov     x0, #1
    cmp     x0, #1
    expect_branch eq, 0x01

    /* 0x02: CMP (imm) -> B.ne */
    mov     x0, #2
    cmp     x0, #1
    expect_branch ne, 0x02

    /* 0x03: SUBS compare-like (reg) -> B.cs */
    mov     x0, #5
    mov     x1, #3
    subs    xzr, x0, x1
    expect_branch cs, 0x03

    /* 0x04: CMP (reg) -> B.cc */
    mov     x0, #2
    mov     x1, #5
    cmp     x0, x1
    expect_branch cc, 0x04

    /* 0x05: SUBS compare-like (shifted reg) -> B.hi */
    mov     x0, #9
    mov     x1, #4
    subs    xzr, x0, x1, lsl #1
    expect_branch hi, 0x05

    /* 0x06: SUBS compare-like (extended reg) -> B.ls */
    mov     x0, #3
    mov     w1, #2
    subs    xzr, x0, w1, uxtw #1
    expect_branch ls, 0x06

    /* 0x07: CMP (reg) -> B.ge */
    movn    x0, #0            /* -1 */
    movn    x1, #1            /* -2 */
    cmp     x0, x1
    expect_branch ge, 0x07

    /* 0x08: CMP (reg) -> B.lt */
    movn    x0, #1            /* -2 */
    movn    x1, #0            /* -1 */
    cmp     x0, x1
    expect_branch lt, 0x08

    /* 0x09: CMP (imm) -> B.gt */
    mov     x0, #2
    cmp     x0, #1
    expect_branch gt, 0x09

    /* 0x0a: CMP (imm) -> B.le */
    mov     x0, #1
    cmp     x0, #1
    expect_branch le, 0x0a

    /* 0x0b: CMP (imm) -> B.mi */
    mov     x0, #0
    cmp     x0, #1
    expect_branch mi, 0x0b

    /* 0x0c: CMP (imm) -> B.pl */
    mov     x0, #1
    cmp     x0, #0
    expect_branch pl, 0x0c

    /* 0x0d: CMP (reg) -> B.vs */
    mov     x0, #1
    lsl     x0, x0, #63       /* INT64_MIN */
    mov     x1, #1
    cmp     x0, x1
    expect_branch vs, 0x0d

    /* 0x0e: CMP (reg) -> B.vc */
    mov     x0, #5
    mov     x1, #1
    cmp     x0, x1
    expect_branch vc, 0x0e

    /* 0x0f: CMP + NOP + CSEL (eq) */
    mov     x0, #7
    cmp     x0, #7
    nop
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 11, 0x0f

    /* 0x10: CMP + NOP + CSEL (cs false) */
    mov     x0, #2
    mov     x1, #5
    cmp     x0, x1
    nop
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, cs
    expect_reg_imm x2, 22, 0x10

    /* 0x11: CMP + NOP + CSEL (lt true) */
    movn    x0, #1            /* -2 */
    movn    x1, #0            /* -1 */
    cmp     x0, x1
    nop
    mov     x3, #33
    mov     x4, #44
    csel    x2, x3, x4, lt
    expect_reg_imm x2, 33, 0x11

    /* 0x12: CMP + NOP + MRS NZCV, equal result */
    mov     x0, #5
    cmp     x0, #5
    nop
    expect_nzcv 0x6, 0x12

    /* 0x13: CMP + NOP + MRS NZCV, borrow negative result */
    mov     x0, #2
    cmp     x0, #5
    nop
    expect_nzcv 0x8, 0x13

    /* 0x14: CMP + NOP + MRS NZCV, signed overflow */
    mov     x0, #1
    lsl     x0, x0, #63       /* INT64_MIN */
    mov     x1, #1
    cmp     x0, x1
    nop
    expect_nzcv 0x3, 0x14

    /* 0x15: CMP + NOP + ADC, carry in = 1 */
    mov     x0, #5
    mov     x1, #3
    cmp     x0, x1
    nop
    mov     x2, #10
    mov     x3, #20
    adc     x4, x2, x3
    expect_reg_imm x4, 31, 0x15

    /* 0x16: CMP + NOP + ADC, carry in = 0 */
    mov     x0, #1
    mov     x1, #3
    cmp     x0, x1
    nop
    mov     x2, #10
    mov     x3, #20
    adc     x4, x2, x3
    expect_reg_imm x4, 30, 0x16

    /* 0x17: CMP + NOP + SBC, carry in = 1 */
    mov     x0, #5
    mov     x1, #3
    cmp     x0, x1
    nop
    mov     x2, #5
    mov     x3, #2
    sbc     x4, x2, x3
    expect_reg_imm x4, 3, 0x17

    /* 0x18: CMP + NOP + SBC, carry in = 0 */
    mov     x0, #1
    mov     x1, #3
    cmp     x0, x1
    nop
    mov     x2, #5
    mov     x3, #2
    sbc     x4, x2, x3
    expect_reg_imm x4, 2, 0x18

    /* 0x19: CCMP condition true, take second compare flags */
    mov     x0, #9
    cmp     x0, #9
    mov     x1, #4
    mov     x2, #4
    ccmp    x1, x2, #0x0, eq
    expect_nzcv 0x6, 0x19

    /* 0x1a: CCMP condition false, take literal NZCV */
    mov     x0, #1
    cmp     x0, #2
    mov     x1, #4
    mov     x2, #4
    ccmp    x1, x2, #0xa, eq
    expect_nzcv 0xa, 0x1a

    /* 0x1b: CFINV invalidates cached compare flags and still consumes CF */
    mov     x0, #5
    mov     x1, #3
    cmp     x0, x1
    cfinv
    expect_nzcv 0x0, 0x1b

    /* 0x1c: RMIF overwrites NZCV through the split-flags fallback path */
    mov     x0, #0x6
    rmif    x0, #0, #0xf
    expect_nzcv 0x6, 0x1c

    /* 0x1d: SETF8 updates NZV while preserving the prior C */
    mov     x0, #0
    cmp     x0, #1            /* C = 0 */
    mov     x0, #0x80
    setf8   w0
    expect_nzcv 0x9, 0x1d

    /* 0x1e: CMP + NOP + FCSEL consumes integer NZCV */
    mov     x0, #3
    cmp     x0, #3
    nop
    fmov    d2, #2.0
    fmov    d3, #0.5
    fcsel   d4, d2, d3, eq
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    mov     x20, #0x1e
    cmp     x5, x6
    b.eq    1f
    b       fail
1:

    /* 0x1f: FCCMP condition true, consume integer NZCV and compare floats */
    mov     x0, #1
    cmp     x0, #1
    fmov    d0, #1.0
    fmov    d1, #1.0
    fccmp   d0, d1, #0x0, eq
    expect_nzcv 0x6, 0x1f

    /* 0x20: FCCMP condition false, take literal NZCV */
    mov     x0, #1
    cmp     x0, #2
    fmov    d0, #1.0
    fmov    d1, #2.0
    fccmp   d0, d1, #0xa, eq
    expect_nzcv 0xa, 0x20

    /* 0x21: Adjacent CMP -> B.eq, with no insns in between */
    mov     x0, #1
    cmp     x0, #1
    b.eq    t21_ok
    mov     x20, #0x21
    b       fail
t21_ok:

    /* 0x22: CMP + B + 4 unrelated insns + MRS NZCV */
    mov     x0, #2
    cmp     x0, #5
    b       t22_target
t22_target:
    mov     x3, #1
    eor     x4, x3, x3
    orr     x5, x3, x3
    add     x6, x5, #7
    mrs     x2, nzcv
    lsr     x2, x2, #28
    expect_reg_imm x2, 0x8, 0x22

    /* 0x23: CMP + B + CMP producer + unrelated insns + CSEL */
    mov     x0, #9
    cmp     x0, #9
    b       t23_target
t23_target:
    mov     x0, #2
    cmp     x0, #5
    mov     x3, #11
    mov     x4, #22
    eor     x5, x3, x4
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 22, 0x23

    /* 0x24: CMP + B + RMIF producer + unrelated insns + CSEL */
    mov     x0, #9
    cmp     x0, #9
    b       t24_target
t24_target:
    mov     x0, #0x9
    rmif    x0, #0, #0xf
    mov     x3, #11
    mov     x4, #22
    eor     x5, x3, x4
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 22, 0x24

    /* 0x25: CMP + B + B + CSEL */
    mov     x0, #7
    cmp     x0, #7
    b       t25_mid
t25_mid:
    b       t25_target
t25_target:
    mov     x3, #33
    mov     x4, #44
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 33, 0x25

    /* 0x26: CMP producer TB -> shared consumer TB */
    mov     x14, #0x6
    adr     x15, t26_after
    mov     x0, #5
    cmp     x0, #5
    b       shared_nzcv_consumer
t26_after:
    expect_reg_reg x2, x14, 0x26

    /* 0x27: RMIF producer TB -> shared consumer TB */
    mov     x14, #0x9
    adr     x15, t27_after
    mov     x0, #0x9
    rmif    x0, #0, #0xf
    b       shared_nzcv_consumer
t27_after:
    expect_reg_reg x2, x14, 0x27

    /* 0x28: SETF8 producer TB -> shared consumer TB */
    mov     x14, #0x2
    adr     x15, t28_after
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 for SETF8 */
    mov     x0, #0x7f
    setf8   w0
    b       shared_nzcv_consumer
t28_after:
    expect_reg_reg x2, x14, 0x28

    /* 0x29: Adjacent 32-bit CMP -> B.eq */
    mov     w0, #1
    cmp     w0, #1
    b.eq    t29_ok
    mov     x20, #0x29
    b       fail
t29_ok:

    /* 0x2a: Adjacent 32-bit CMP -> CSEL */
    mov     x3, #55
    mov     x4, #66
    mov     w0, #1
    lsl     w0, w0, #31       /* INT32_MIN */
    mov     w1, #1
    cmp     w0, w1
    csel    x2, x3, x4, lt
    expect_reg_imm x2, 55, 0x2a

    /* 0x2b: 32-bit CMP -> MRS NZCV */
    movn    w0, #0            /* 0xffffffff */
    mov     w1, #0
    cmp     w0, w1
    mrs     x2, nzcv
    lsr     x2, x2, #28
    expect_reg_imm x2, 0xa, 0x2b

    /* 0x2c: MSR NZCV -> B.mi via split fallback */
    movz    x0, #0x8000, lsl #16
    msr     nzcv, x0
    b.mi    t2c_ok
    mov     x20, #0x2c
    b       fail
t2c_ok:

    /* 0x2d: MSR NZCV -> CSEL via split fallback */
    movz    x0, #0x6000, lsl #16
    msr     nzcv, x0
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 11, 0x2d

    /* 0x2e: MSR NZCV -> ADC via split fallback */
    movz    x0, #0x2000, lsl #16
    msr     nzcv, x0
    mov     x2, #10
    mov     x3, #20
    adc     x4, x2, x3
    expect_reg_imm x4, 31, 0x2e

    /* 0x2f: MSR NZCV -> MRS NZCV via split fallback */
    movz    x0, #0x1000, lsl #16
    msr     nzcv, x0
    expect_nzcv 0x1, 0x2f

    /* 0x30: ANDS/TST fallback -> B.eq */
    mov     x0, #3
    mov     x1, #4
    ands    xzr, x0, x1
    b.eq    t30_ok
    mov     x20, #0x30
    b       fail
t30_ok:

    /* 0x31: TST fallback -> CSEL */
    mov     x0, #3
    mov     x1, #1
    tst     x0, x1
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 22, 0x31

    /* 0x32: ADDS fallback -> B.vs */
    mov     x0, #1
    lsl     x0, x0, #63
    sub     x0, x0, #1        /* INT64_MAX */
    mov     x1, #1
    adds    xzr, x0, x1
    b.vs    t32_ok
    mov     x20, #0x32
    b       fail
t32_ok:

    /* 0x33: CMN fallback -> ADC */
    movn    x0, #0            /* -1 */
    mov     x1, #1
    cmn     x0, x1
    mov     x2, #10
    mov     x3, #20
    adc     x4, x2, x3
    expect_reg_imm x4, 31, 0x33

    /* 0x34: CMP producer TB -> shared CSEL consumer TB */
    mov     x14, #55
    adr     x15, t34_after
    mov     x3, #55
    mov     x4, #66
    mov     x0, #5
    cmp     x0, #5
    b       shared_csel_consumer
t34_after:
    expect_reg_reg x2, x14, 0x34

    /* 0x35: CMP producer TB -> shared ADC consumer TB */
    mov     x14, #31
    adr     x15, t35_after
    mov     x5, #10
    mov     x6, #20
    mov     x0, #7
    cmp     x0, #5
    b       shared_adc_consumer
t35_after:
    expect_reg_reg x2, x14, 0x35

    /* 0x36: CMP producer TB -> shared SBC consumer TB */
    mov     x14, #2
    adr     x15, t36_after
    mov     x5, #5
    mov     x6, #2
    mov     x0, #1
    cmp     x0, #3
    b       shared_sbc_consumer
t36_after:
    expect_reg_reg x2, x14, 0x36

    /* 0x37: Adjacent CMP -> CSEL */
    mov     x3, #77
    mov     x4, #88
    mov     x0, #9
    cmp     x0, #9
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 77, 0x37
    expect_nzcv 0x6, 0x37

    /* 0x38: Adjacent CMP -> FCSEL */
    fmov    d2, #4.0
    fmov    d3, #1.0
    mov     x0, #9
    cmp     x0, #9
    fcsel   d4, d2, d3, eq
    expect_nzcv 0x6, 0x38
    fmov    x5, d4
    ldr     x6, =0x4010000000000000
    mov     x20, #0x38
    cmp     x5, x6
    b.eq    1f
    b       fail
1:

    /* 0x39: Adjacent CMP -> CCMP (condition true) */
    mov     x1, #4
    mov     x2, #4
    mov     x0, #9
    cmp     x0, #9
    ccmp    x1, x2, #0x0, eq
    expect_nzcv 0x6, 0x39

    /* 0x3a: Adjacent CMP -> CCMP (condition false literal) */
    mov     x1, #4
    mov     x2, #4
    mov     x0, #1
    cmp     x0, #2
    ccmp    x1, x2, #0xa, eq
    expect_nzcv 0xa, 0x3a

    /* 0x3b: Adjacent CMP -> FCCMP (condition true) */
    fmov    d0, #1.0
    fmov    d1, #1.0
    mov     x0, #1
    cmp     x0, #1
    fccmp   d0, d1, #0x0, eq
    expect_nzcv 0x6, 0x3b

    /* 0x3c: Adjacent CMP -> FCCMP (condition false literal) */
    fmov    d0, #1.0
    fmov    d1, #2.0
    mov     x0, #1
    cmp     x0, #2
    fccmp   d0, d1, #0xa, eq
    expect_nzcv 0xa, 0x3c

    /* 0x3d: Adjacent 32-bit CMP -> B.ne */
    mov     w0, #2
    cmp     w0, #1
    b.ne    t3d_ok
    mov     x20, #0x3d
    b       fail
t3d_ok:

    /* 0x3e: Adjacent 32-bit CMP -> B.cs */
    mov     w0, #5
    mov     w1, #3
    cmp     w0, w1
    b.cs    t3e_ok
    mov     x20, #0x3e
    b       fail
t3e_ok:

    /* 0x3f: Adjacent 32-bit CMP -> B.cc */
    mov     w0, #2
    mov     w1, #5
    cmp     w0, w1
    b.cc    t3f_ok
    mov     x20, #0x3f
    b       fail
t3f_ok:

    /* 0x40: Adjacent 32-bit CMP overflow -> B.vs */
    mov     w0, #1
    lsl     w0, w0, #31       /* INT32_MIN */
    mov     w1, #1
    cmp     w0, w1
    b.vs    t40_ok
    mov     x20, #0x40
    b       fail
t40_ok:

    /* 0x41: Adjacent 32-bit CMP -> ADC */
    mov     w0, #5
    mov     w1, #3
    cmp     w0, w1
    mov     x2, #10
    mov     x3, #20
    adc     x4, x2, x3
    expect_reg_imm x4, 31, 0x41

    /* 0x42: MSR NZCV -> B.eq via split fallback */
    movz    x0, #0x6000, lsl #16
    msr     nzcv, x0
    b.eq    t42_ok
    mov     x20, #0x42
    b       fail
t42_ok:

    /* 0x43: MSR NZCV -> B.cs via split fallback */
    movz    x0, #0x2000, lsl #16
    msr     nzcv, x0
    b.cs    t43_ok
    mov     x20, #0x43
    b       fail
t43_ok:

    /* 0x44: MSR NZCV -> B.vs via split fallback */
    movz    x0, #0x1000, lsl #16
    msr     nzcv, x0
    b.vs    t44_ok
    mov     x20, #0x44
    b       fail
t44_ok:

    /* 0x45: MSR NZCV -> SBC via split fallback */
    movz    x0, #0x2000, lsl #16
    msr     nzcv, x0
    mov     x2, #5
    mov     x3, #2
    sbc     x4, x2, x3
    expect_reg_imm x4, 3, 0x45

    /* 0x46: CMP + 1 unrelated insn + B.eq */
    mov     x0, #7
    cmp     x0, #7
    mov     x9, #123
    b.eq    t46_ok
    mov     x20, #0x46
    b       fail
t46_ok:
    expect_reg_imm x9, 123, 0x46

    /* 0x47: CMP + 4 unrelated insns + CSEL */
    mov     x0, #2
    cmp     x0, #5
    mov     x7, #1
    eor     x8, x7, x7
    orr     x9, x7, x7
    add     x10, x9, #7
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 22, 0x47

    /* 0x48: CMP + 8 unrelated insns + ADC */
    mov     x0, #5
    mov     x1, #3
    cmp     x0, x1
    mov     x7, #1
    mov     x8, #2
    eor     x9, x7, x8
    orr     x10, x7, x8
    add     x11, x10, #7
    sub     x12, x11, #3
    lsl     x13, x12, #1
    lsr     x14, x13, #1
    mov     x2, #10
    mov     x3, #20
    adc     x4, x2, x3
    expect_reg_imm x4, 31, 0x48

    /* 0x49: CMP + 8 unrelated insns + MRS NZCV */
    mov     x0, #2
    cmp     x0, #5
    mov     x7, #1
    mov     x8, #2
    eor     x9, x7, x8
    orr     x10, x7, x8
    add     x11, x10, #7
    sub     x12, x11, #3
    lsl     x13, x12, #1
    lsr     x14, x13, #1
    mrs     x2, nzcv
    lsr     x2, x2, #28
    expect_reg_imm x2, 0x8, 0x49

    /* 0x4a: CMP producer TB -> shared B.eq consumer TB */
    mov     x14, #1
    adr     x15, t4a_after
    mov     x0, #5
    cmp     x0, #5
    b       shared_bcond_eq_consumer
t4a_after:
    expect_reg_reg x2, x14, 0x4a

    /* 0x4b: RMIF producer TB -> shared B.eq consumer TB */
    mov     x14, #1
    adr     x15, t4b_after
    mov     x0, #0x6
    rmif    x0, #0, #0xf
    b       shared_bcond_eq_consumer
t4b_after:
    expect_reg_reg x2, x14, 0x4b

    /* 0x4c: SETF8 producer TB -> shared B.eq consumer TB */
    mov     x14, #1
    adr     x15, t4c_after
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 for SETF8 */
    mov     x0, #0
    setf8   w0
    b       shared_bcond_eq_consumer
t4c_after:
    expect_reg_reg x2, x14, 0x4c

    /* 0x4d: MSR NZCV producer TB -> shared B.eq consumer TB */
    mov     x14, #1
    adr     x15, t4d_after
    movz    x0, #0x6000, lsl #16
    msr     nzcv, x0
    b       shared_bcond_eq_consumer
t4d_after:
    expect_reg_reg x2, x14, 0x4d

    /* 0x4e: MSR NZCV producer TB -> shared CSEL consumer TB */
    mov     x14, #11
    adr     x15, t4e_after
    mov     x3, #11
    mov     x4, #22
    movz    x0, #0x6000, lsl #16
    msr     nzcv, x0
    b       shared_csel_consumer
t4e_after:
    expect_reg_reg x2, x14, 0x4e

    /* 0x4f: MSR NZCV producer TB -> shared ADC consumer TB */
    mov     x14, #31
    adr     x15, t4f_after
    mov     x5, #10
    mov     x6, #20
    movz    x0, #0x2000, lsl #16
    msr     nzcv, x0
    b       shared_adc_consumer
t4f_after:
    expect_reg_reg x2, x14, 0x4f

    /* 0x50: CMP + B + ADDS producer + CSEL */
    mov     x0, #9
    cmp     x0, #9
    b       t50_target
t50_target:
    mov     x0, #1
    lsl     x0, x0, #63       /* INT64_MIN */
    sub     x0, x0, #1        /* INT64_MAX */
    adds    xzr, x0, #1
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, vs
    expect_reg_imm x2, 11, 0x50

    /* 0x51: CMP + B + ANDS producer + CSEL */
    mov     x0, #9
    cmp     x0, #9
    b       t51_target
t51_target:
    mov     x0, #3
    mov     x1, #4
    ands    xzr, x0, x1
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, eq
    expect_reg_imm x2, 11, 0x51

    /* 0x52: CMP + B + CFINV producer + ADC */
    mov     x0, #9
    cmp     x0, #5            /* Seed C = 1 */
    b       t52_target
t52_target:
    cfinv
    mov     x2, #10
    mov     x3, #20
    adc     x4, x2, x3
    expect_reg_imm x4, 30, 0x52

    /* 0x53: CMP + B + MSR NZCV producer + CSEL */
    mov     x0, #9
    cmp     x0, #9
    b       t53_target
t53_target:
    movz    x0, #0x8000, lsl #16
    msr     nzcv, x0
    mov     x3, #11
    mov     x4, #22
    csel    x2, x3, x4, mi
    expect_reg_imm x2, 11, 0x53

    /* 0x54: RMIF -> CCMP -> CSEL */
    mov     x0, #0x6
    rmif    x0, #0, #0xf
    mov     x1, #4
    mov     x2, #4
    ccmp    x1, x2, #0xa, eq
    mov     x3, #11
    mov     x4, #22
    csel    x5, x3, x4, eq
    expect_reg_imm x5, 11, 0x54

    /* 0x55: MSR NZCV -> CCMP -> CSEL */
    movz    x0, #0x6000, lsl #16
    msr     nzcv, x0
    mov     x1, #2
    mov     x2, #5
    ccmp    x1, x2, #0xa, eq
    mov     x3, #11
    mov     x4, #22
    csel    x5, x3, x4, eq
    expect_reg_imm x5, 22, 0x55

    /* 0x56: Adjacent CMP -> CCMN (condition true) */
    movn    x1, #0            /* -1 */
    mov     x2, #1
    mov     x0, #1
    cmp     x0, #1
    ccmn    x1, x2, #0xa, eq
    expect_nzcv 0x6, 0x56

    /* 0x57: Adjacent CMP -> CCMN (condition false literal) */
    movn    x1, #0            /* -1 */
    mov     x2, #1
    mov     x0, #1
    cmp     x0, #2
    ccmn    x1, x2, #0xa, eq
    expect_nzcv 0xa, 0x57

    /* 0x58: MSR NZCV -> FCSEL via split fallback */
    movz    x0, #0x6000, lsl #16
    msr     nzcv, x0
    fmov    d2, #2.0
    fmov    d3, #0.5
    fcsel   d4, d2, d3, eq
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    mov     x20, #0x58
    cmp     x5, x6
    b.eq    1f
    b       fail
1:

    /* 0x59: RMIF -> FCSEL */
    mov     x0, #0x6
    rmif    x0, #0, #0xf
    fmov    d2, #2.0
    fmov    d3, #0.5
    fcsel   d4, d2, d3, eq
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    mov     x20, #0x59
    cmp     x5, x6
    b.eq    1f
    b       fail
1:

    /* 0x5a: CMP + 4 unrelated insns + FCSEL */
    mov     x0, #3
    cmp     x0, #3
    mov     x7, #1
    eor     x8, x7, x7
    orr     x9, x7, x7
    add     x10, x9, #7
    fmov    d2, #2.0
    fmov    d3, #0.5
    fcsel   d4, d2, d3, eq
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    mov     x20, #0x5a
    cmp     x5, x6
    b.eq    1f
    b       fail
1:

    /* 0x5b: adjacent CMP + B.mi (64-bit) */
    mov     x0, #0
    cmp     x0, #1
    b.mi    t5b_ok
    mov     x20, #0x5b
    b       fail
t5b_ok:

    /* 0x5c: adjacent CMP + B.pl (64-bit) */
    mov     x0, #2
    cmp     x0, #1
    b.pl    t5c_ok
    mov     x20, #0x5c
    b       fail
t5c_ok:

    /* 0x5d: adjacent CMP + B.vs (64-bit) */
    mov     x0, #1
    lsl     x0, x0, #63
    mov     x1, #1
    cmp     x0, x1
    b.vs    t5d_ok
    mov     x20, #0x5d
    b       fail
t5d_ok:

    /* 0x5e: adjacent CMP + B.vc (64-bit) */
    mov     x0, #5
    cmp     x0, #1
    b.vc    t5e_ok
    mov     x20, #0x5e
    b       fail
t5e_ok:

    /* 0x5f: adjacent CMP + B.mi (32-bit) */
    mov     w0, #0
    cmp     w0, #1
    b.mi    t5f_ok
    mov     x20, #0x5f
    b       fail
t5f_ok:

    /* 0x60: adjacent CMP + B.pl (32-bit) */
    mov     w0, #2
    cmp     w0, #1
    b.pl    t60_ok
    mov     x20, #0x60
    b       fail
t60_ok:

    /* 0x61: adjacent CMP + B.vs (32-bit) */
    mov     w0, #1
    lsl     w0, w0, #31
    mov     w1, #1
    cmp     w0, w1
    b.vs    t61_ok
    mov     x20, #0x61
    b       fail
t61_ok:

    /* 0x62: adjacent CMP + B.vc (32-bit) */
    mov     w0, #5
    cmp     w0, #1
    b.vc    t62_ok
    mov     x20, #0x62
    b       fail
t62_ok:

    /* 0x63: Adjacent CMP -> CSEL -> ADC preserves carry and NZCV */
    mov     x3, #11
    mov     x4, #22
    mov     x5, #10
    mov     x6, #20
    mov     x0, #5
    cmp     x0, #3
    csel    x2, x3, x4, eq
    adc     x7, x5, x6
    expect_nzcv 0x2, 0x63
    expect_reg_imm x2, 22, 0x63
    expect_reg_imm x7, 31, 0x63

    /* 0x64: Adjacent CMP -> CSEL -> CFINV consumes canonical carry only */
    mov     x3, #11
    mov     x4, #22
    mov     x0, #5
    cmp     x0, #3
    csel    x2, x3, x4, cs
    cfinv
    expect_nzcv 0x0, 0x64
    expect_reg_imm x2, 11, 0x64

    /* 0x65: Adjacent CMP -> FCSEL -> ADC preserves flags */
    fmov    d2, #2.0
    fmov    d3, #0.5
    mov     x5, #10
    mov     x6, #20
    mov     x0, #9
    cmp     x0, #9
    fcsel   d4, d2, d3, eq
    adc     x7, x5, x6
    expect_nzcv 0x6, 0x65
    expect_reg_imm x7, 31, 0x65
    fmov    x8, d4
    ldr     x9, =0x4000000000000000
    mov     x20, #0x65
    cmp     x8, x9
    b.eq    1f
    b       fail
1:

    /* 0x66: Adjacent 32-bit CMP -> CSEL -> ADC preserves 32-bit carry */
    mov     x3, #11
    mov     x4, #22
    mov     x5, #10
    mov     x6, #20
    mov     w0, #5
    mov     w1, #3
    cmp     w0, w1
    csel    x2, x3, x4, cs
    adc     x7, x5, x6
    expect_nzcv 0x2, 0x66
    expect_reg_imm x2, 11, 0x66
    expect_reg_imm x7, 31, 0x66

    /* 0x67: Adjacent CMP -> CSEL -> B.eq preserves condition flags */
    mov     x3, #55
    mov     x4, #66
    mov     x0, #7
    cmp     x0, #7
    csel    x2, x3, x4, eq
    b.eq    t67_ok
    mov     x20, #0x67
    b       fail
t67_ok:
    expect_reg_imm x2, 55, 0x67

    /* 0x68: CMP -> RMIF(mask=C) preserves canonical N/Z/V */
    mov     x0, #0
    cmp     x0, #1
    mov     x0, #0x2
    rmif    x0, #0, #0x2
    expect_nzcv 0xa, 0x68

    /* 0x69: CMP -> RMIF(mask=NZV) preserves canonical C */
    mov     x0, #5
    cmp     x0, #3
    mov     x0, #0x9
    rmif    x0, #0, #0xd
    expect_nzcv 0xb, 0x69

    /* 0x6a: CMP -> SETF8 preserves canonical carry=1 */
    mov     x0, #5
    cmp     x0, #3
    mov     w0, #0x80
    setf8   w0
    expect_nzcv 0xb, 0x6a

    /* 0x6b: CMP -> SETF16 preserves canonical carry=1 */
    mov     x0, #5
    cmp     x0, #3
    mov     w0, #0x8000
    setf16  w0
    expect_nzcv 0xb, 0x6b

    /* 0x6c: CMP -> CFINV preserves canonical N/Z/V while flipping C */
    mov     x0, #0
    cmp     x0, #1
    cfinv
    expect_nzcv 0xa, 0x6c

    /* 0x6d: Adjacent CMP -> CSET -> ADC preserves carry */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #7
    cmp     x0, #7
    cset    x2, eq
    adc     x7, x5, x6
    expect_nzcv 0x6, 0x6d
    expect_reg_imm x2, 1, 0x6d
    expect_reg_imm x7, 31, 0x6d

    /* 0x6e: Adjacent CMP -> CSETM -> ADC preserves carry */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #5
    cmp     x0, #3
    csetm   x2, ne
    adc     x7, x5, x6
    movn    x8, #0
    expect_nzcv 0x2, 0x6e
    expect_reg_reg x2, x8, 0x6e
    expect_reg_imm x7, 31, 0x6e

    /* 0x6f: Adjacent CMP -> CSINC -> ADC preserves carry */
    mov     x3, #100
    mov     x4, #55
    mov     x5, #10
    mov     x6, #20
    mov     x0, #7
    cmp     x0, #6
    csinc   x2, x3, x4, eq
    adc     x7, x5, x6
    expect_nzcv 0x2, 0x6f
    expect_reg_imm x2, 56, 0x6f
    expect_reg_imm x7, 31, 0x6f

    /* 0x70: Adjacent CMP -> CSINV -> flags remain live */
    mov     x3, #100
    mov     x4, #55
    mov     x0, #7
    cmp     x0, #6
    csinv   x2, x3, x4, eq
    mvn     x8, x4
    expect_nzcv 0x2, 0x70
    expect_reg_reg x2, x8, 0x70

    /* 0x71: Adjacent CMP -> CSNEG -> flags remain live */
    mov     x3, #100
    mov     x4, #55
    mov     x0, #0
    cmp     x0, #1
    csneg   x2, x3, x4, eq
    neg     x8, x4
    expect_nzcv 0x8, 0x71
    expect_reg_reg x2, x8, 0x71

    b       after_shared_consumers

shared_nzcv_consumer:
    mrs     x2, nzcv
    lsr     x2, x2, #28
    br      x15

shared_csel_consumer:
    csel    x2, x3, x4, eq
    br      x15

shared_adc_consumer:
    adc     x2, x5, x6
    br      x15

shared_sbc_consumer:
    sbc     x2, x5, x6
    br      x15

shared_bcond_eq_consumer:
    b.eq    1f
    mov     x2, #0
    br      x15
1:
    mov     x2, #1
    br      x15

after_shared_consumers:

pass:
    mov     x0, #1
    adr     x1, pass_msg
    mov     x2, #5
    mov     x8, #64           /* write */
    svc     #0

    mov     x0, #0
    mov     x8, #93           /* exit */
    svc     #0

fail:
    adr     x10, fail_msg
    adr     x11, hex_digits

    ubfx    x12, x20, #4, #4
    ldrb    w13, [x11, x12]
    strb    w13, [x10, #5]

    and     x12, x20, #0xf
    ldrb    w13, [x11, x12]
    strb    w13, [x10, #6]

    mov     x0, #1
    mov     x1, x10
    mov     x2, #8
    mov     x8, #64           /* write */
    svc     #0

    mov     x0, x20
    mov     x8, #93           /* exit */
    svc     #0

    .section .rodata
pass_msg:
    .ascii  "PASS\n"
fail_msg:
    .ascii  "FAIL 00\n"
hex_digits:
    .ascii  "0123456789ABCDEF"
