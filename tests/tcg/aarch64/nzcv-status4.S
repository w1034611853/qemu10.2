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

    /* 0x72: Adjacent CMP -> B.eq taken -> ADC via saved canonical flags */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #4
    cmp     x0, #4
    b.eq    t72_ok
    mov     x20, #0x72
    b       fail
t72_ok:
    adc     x7, x5, x6
    expect_nzcv 0x6, 0x72
    expect_reg_imm x7, 31, 0x72

    /* 0x73: Adjacent CMP -> B.eq fallthrough -> ADC via saved canonical flags */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #4
    cmp     x0, #5
    b.eq    t73_bad
    adc     x7, x5, x6
    expect_nzcv 0x8, 0x73
    expect_reg_imm x7, 30, 0x73
    b       t73_done
t73_bad:
    mov     x20, #0x73
    b       fail
t73_done:

    /* 0x74: Adjacent CMP -> B.vs taken preserves overflow flags */
    mov     x0, #1
    lsl     x0, x0, #63
    mov     x1, #1
    cmp     x0, x1
    b.vs    t74_ok
    mov     x20, #0x74
    b       fail
t74_ok:
    expect_nzcv 0x3, 0x74

    /* 0x75: Adjacent CMP -> B.mi fallthrough preserves non-negative flags */
    mov     x0, #7
    cmp     x0, #7
    b.mi    t75_bad
    expect_nzcv 0x6, 0x75
    b       t75_done
t75_bad:
    mov     x20, #0x75
    b       fail
t75_done:

    /* 0x76: CMP + safe gap rewriting lhs -> B.eq taken using original flags */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #7
    cmp     x0, #7
    add     x0, x0, #1
    mov     x9, #123
    add     x9, x9, #1
    eor     x10, x9, x9
    b.eq    t76_ok
    mov     x20, #0x76
    b       fail
t76_ok:
    adc     x7, x5, x6
    mrs     x11, nzcv
    lsr     x11, x11, #28
    expect_reg_imm x0, 8, 0x76
    expect_reg_imm x7, 31, 0x76
    expect_reg_imm x11, 6, 0x76

    /* 0x77: CMP + safe gap rewriting lhs -> B.eq fallthrough keeps old flags */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #7
    cmp     x0, #5
    sub     x0, x0, #2
    mov     x9, #1
    add     x9, x9, #2
    eor     x10, x9, x9
    b.eq    t77_bad
    adc     x7, x5, x6
    mrs     x11, nzcv
    lsr     x11, x11, #28
    expect_reg_imm x0, 5, 0x77
    expect_reg_imm x7, 31, 0x77
    expect_reg_imm x11, 2, 0x77
    b       t77_done
t77_bad:
    mov     x20, #0x77
    b       fail
t77_done:

    /* 0x78: CMP (reg) + safe gap rewriting both inputs -> B.eq uses snapshots */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #9
    mov     x1, #9
    cmp     x0, x1
    add     x0, x0, #5
    sub     x1, x1, #4
    mov     x9, #3
    eor     x10, x9, x9
    b.eq    t78_ok
    mov     x20, #0x78
    b       fail
t78_ok:
    adc     x7, x5, x6
    mrs     x11, nzcv
    lsr     x11, x11, #28
    expect_reg_imm x0, 14, 0x78
    expect_reg_imm x1, 5, 0x78
    expect_reg_imm x7, 31, 0x78
    expect_reg_imm x11, 6, 0x78

    /* 0x79: CMP + safe gap + B.vs keeps overflow from original compare */
    mov     x0, #1
    lsl     x0, x0, #63
    mov     x1, #1
    cmp     x0, x1
    add     x0, x0, #1
    mov     x9, #1
    add     x9, x9, #2
    eor     x10, x9, x9
    b.vs    t79_ok
    mov     x20, #0x79
    b       fail
t79_ok:
    mrs     x11, nzcv
    lsr     x11, x11, #28
    expect_reg_imm x11, 3, 0x79

    /* 0x7a: CMP raw flags -> XAFLAG -> ADC consumes updated carry */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #1
    lsl     x0, x0, #63       /* INT64_MIN */
    mov     x1, #1
    cmp     x0, x1
    xaflag
    adc     x7, x5, x6
    expect_nzcv 0x2, 0x7a
    expect_reg_imm x7, 31, 0x7a

    /* 0x7b: CMP raw flags -> AXFLAG -> ADC consumes updated carry */
    mov     x5, #10
    mov     x6, #20
    mov     x0, #1
    lsl     x0, x0, #63       /* INT64_MIN */
    mov     x1, #1
    cmp     x0, x1
    axflag
    adc     x7, x5, x6
    expect_nzcv 0x4, 0x7b
    expect_reg_imm x7, 30, 0x7b

    /* 0x7c: CMP + B.eq fallthrough -> CSEL(hi) consumes raw composite cond */
    mov     x3, #77
    mov     x4, #88
    mov     x0, #9
    cmp     x0, #5
    b.eq    t7c_bad
    csel    x2, x3, x4, hi
    expect_nzcv 0x2, 0x7c
    expect_reg_imm x2, 77, 0x7c
    b       t7c_done
t7c_bad:
    mov     x20, #0x7c
    b       fail
t7c_done:

    /* 0x7d: CMP + B.eq fallthrough -> FCSEL(gt) consumes raw composite cond */
    fmov    d2, #8.0
    fmov    d3, #1.0
    mov     x0, #2
    cmp     x0, #1
    b.eq    t7d_bad
    fcsel   d4, d2, d3, gt
    expect_nzcv 0x2, 0x7d
    fmov    x5, d4
    ldr     x6, =0x4020000000000000
    mov     x20, #0x7d
    cmp     x5, x6
    b.eq    1f
    b       fail
1:
    b       t7d_done
t7d_bad:
    mov     x20, #0x7d
    b       fail
t7d_done:

    /* 0x7e: CMP + B.eq fallthrough -> FCCMP(gt) consumes raw composite cond */
    mov     x0, #2
    cmp     x0, #1
    b.eq    t7e_bad
    fmov    d0, #1.0
    fmov    d1, #1.0
    fccmp   d0, d1, #0xa, gt
    expect_nzcv 0x6, 0x7e
    b       t7e_done
t7e_bad:
    mov     x20, #0x7e
    b       fail
t7e_done:

    /* 0x7f: CMP + B.eq fallthrough -> SETF8 preserves raw canonical carry */
    mov     x0, #5
    cmp     x0, #3
    b.eq    t7f_bad
    mov     w0, #0x80
    setf8   w0
    expect_nzcv 0xb, 0x7f
    b       t7f_done
t7f_bad:
    mov     x20, #0x7f
    b       fail
t7f_done:

    /* 0x80: CCMP true -> ADC consumes carry from synthetic raw result */
    mov     x0, #1
    cmp     x0, #1
    mov     x1, #5
    mov     x2, #3
    ccmp    x1, x2, #0xa, eq
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x2, 0x80
    expect_reg_imm x7, 31, 0x80

    /* 0x81: CCMN false literal -> ADC consumes literal carry from raw */
    mov     x0, #1
    cmp     x0, #2
    movn    x1, #0            /* -1 */
    mov     x2, #1
    ccmn    x1, x2, #0x8, eq
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x8, 0x81
    expect_reg_imm x7, 30, 0x81

    /* 0x82: TST logical-raw producer -> ADC sees carry=0 */
    mov     x0, #3
    mov     x1, #1
    tst     x0, x1
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x0, 0x82
    expect_reg_imm x7, 30, 0x82

    /* 0x83: ADCS raw producer -> ADC sees carry=1 */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    movn    x1, #0            /* -1 */
    mov     x2, #0
    adcs    xzr, x1, x2
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x6, 0x83
    expect_reg_imm x7, 31, 0x83

    /* 0x84: SBCS raw producer -> ADC sees carry=0 */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    mov     x1, #1
    mov     x2, #3
    sbcs    xzr, x1, x2
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x8, 0x84
    expect_reg_imm x7, 30, 0x84

    /* 0x85: ADDS64 direct raw producer -> B.cs and MRS NZCV */
    movn    x1, #0            /* -1 */
    mov     x2, #1
    adds    x3, x1, x2
    expect_branch cs, 0x85
    expect_nzcv 0x6, 0x85

    /* 0x86: ADDS32 direct raw producer -> MRS NZCV */
    movn    w1, #0            /* 0xffffffff */
    mov     w2, #1
    adds    w3, w1, w2
    expect_nzcv 0x6, 0x86

    /* 0x87: ANDS32 direct raw producer keeps bit31-sign semantics */
    mov     w1, #0x80000000
    movn    w2, #0
    ands    w3, w1, w2
    expect_nzcv 0x8, 0x87

    /* 0x88: ADCS32 direct raw producer -> ADC consumes carry */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    movn    w1, #0            /* 0xffffffff */
    mov     w2, #0
    adcs    w3, w1, w2
    mov     w5, #10
    mov     w6, #20
    adc     w7, w5, w6
    expect_nzcv 0x6, 0x88
    expect_reg_imm x7, 31, 0x88

    /* 0x89: BICS64 direct raw producer -> ADC sees carry=0 */
    mov     x1, #15
    mov     x2, #3
    bics    x3, x1, x2
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x0, 0x89
    expect_reg_imm x3, 12, 0x89
    expect_reg_imm x7, 30, 0x89

    /* 0x8a: TST immediate direct raw producer -> ADC sees carry=0 */
    mov     x0, #3
    tst     x0, #1
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x0, 0x8a
    expect_reg_imm x7, 30, 0x8a

    /* 0x8b: ANDS immediate direct raw producer keeps result and carry=0 */
    mov     x1, #15
    ands    x3, x1, #12
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x0, 0x8b
    expect_reg_imm x3, 12, 0x8b
    expect_reg_imm x7, 30, 0x8b

    /* 0x8c: SUBS64 direct raw producer -> ADC sees carry=1 */
    mov     x1, #5
    mov     x2, #3
    subs    x3, x1, x2
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x2, 0x8c
    expect_reg_imm x3, 2, 0x8c
    expect_reg_imm x7, 31, 0x8c

    /* 0x8d: SBCS direct raw producer keeps carry=1 */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    mov     x1, #5
    mov     x2, #3
    sbcs    x3, x1, x2
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6
    expect_nzcv 0x2, 0x8d
    expect_reg_imm x3, 2, 0x8d
    expect_reg_imm x7, 31, 0x8d

    /* 0x8e: SBCS32 direct raw producer keeps carry=1 */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    mov     w1, #5
    mov     w2, #3
    sbcs    w3, w1, w2
    mov     w5, #10
    mov     w6, #20
    adc     w7, w5, w6
    expect_nzcv 0x2, 0x8e
    expect_reg_imm x3, 2, 0x8e
    expect_reg_imm x7, 31, 0x8e

    /* 0x8f: SBCS compare-like producer -> B.cs */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    mov     x1, #5
    mov     x2, #3
    sbcs    xzr, x1, x2
    expect_branch cs, 0x8f
    expect_nzcv 0x2, 0x8f

    /* 0x90: SBCS compare-like producer -> B.mi */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    mov     x1, #1
    mov     x2, #3
    sbcs    xzr, x1, x2
    expect_branch mi, 0x90
    expect_nzcv 0x8, 0x90

    /* 0x91: ORN64 shifted-reg must behave like ORR with inverted operand */
    mov     x1, #0x123
    mov     x2, #0x5
    lsl     x10, x2, #4
    mvn     x10, x10
    orr     x11, x1, x10
    orn     x3, x1, x2, lsl #4
    expect_reg_reg x3, x11, 0x91

    /* 0x92: EON64 shifted-reg must behave like EOR with inverted operand */
    mov     x1, #0x321
    mov     x2, #0x6
    lsl     x10, x2, #3
    mvn     x10, x10
    eor     x11, x1, x10
    eon     x4, x1, x2, lsl #3
    expect_reg_reg x4, x11, 0x92

    /* 0x93: adjacent CMP + plain SBC uses carry directly but preserves NZCV */
    mov     x0, #5
    mov     x1, #5
    cmp     x0, x1
    mov     x5, #9
    mov     x6, #3
    sbc     x8, x5, x6
    expect_branch eq, 0x93
    expect_nzcv 0x6, 0x93
    expect_reg_imm x8, 6, 0x93

    /* 0x94: adjacent CMN64 + plain ADC preserves NZCV and result */
    mov     x5, #9
    mov     x6, #3
    movn    x0, #0            /* -1 */
    mov     x1, #1
    cmn     x0, x1
    adc     x8, x5, x6
    expect_branch eq, 0x94
    expect_nzcv 0x6, 0x94
    expect_reg_imm x8, 13, 0x94

    /* 0x95: adjacent CMN32 + plain ADC preserves 32-bit carry */
    mov     w5, #9
    mov     w6, #3
    movn    w0, #0            /* -1 */
    mov     w1, #1
    cmn     w0, w1
    adc     w8, w5, w6
    expect_branch eq, 0x95
    expect_nzcv 0x6, 0x95
    expect_reg_imm x8, 13, 0x95

    /* 0x96: adjacent ADDS64 rd + plain ADC preserves result and NZCV */
    movn    x0, #0            /* -1 */
    mov     x1, #1
    mov     x6, #9
    mov     x7, #3
    adds    x5, x0, x1
    adc     x8, x6, x7
    expect_branch eq, 0x96
    expect_nzcv 0x6, 0x96
    expect_reg_imm x5, 0, 0x96
    expect_reg_imm x8, 13, 0x96

    /* 0x97: adjacent ADDS32 rd + plain ADC preserves 32-bit carry */
    movn    w0, #0            /* -1 */
    mov     w1, #1
    mov     w6, #9
    mov     w7, #3
    adds    w5, w0, w1
    adc     w8, w6, w7
    expect_branch eq, 0x97
    expect_nzcv 0x6, 0x97
    expect_reg_imm x5, 0, 0x97
    expect_reg_imm x8, 13, 0x97

    /* 0x98: adjacent SUBS64 rd + plain SBC preserves result and NZCV */
    mov     x0, #0
    mov     x1, #1
    mov     x6, #9
    mov     x7, #3
    subs    x5, x0, x1
    sbc     x8, x6, x7
    movn    x10, #0           /* -1 */
    expect_branch mi, 0x98
    expect_nzcv 0x8, 0x98
    expect_reg_reg x5, x10, 0x98
    expect_reg_imm x8, 5, 0x98

    /* 0x99: adjacent SUBS32 rd + plain SBC preserves 32-bit borrow */
    mov     w0, #0
    mov     w1, #1
    mov     w6, #9
    mov     w7, #3
    subs    w5, w0, w1
    sbc     w8, w6, w7
    movn    w10, #0           /* 0xffffffff */
    expect_branch mi, 0x99
    expect_nzcv 0x8, 0x99
    expect_reg_reg x5, x10, 0x99
    expect_reg_imm x8, 5, 0x99

    /* 0x9a: adjacent CMN64 imm + plain ADC preserves NZCV and result */
    mov     x5, #9
    mov     x6, #3
    movn    x0, #0            /* -1 */
    cmn     x0, #1
    adc     x8, x5, x6
    expect_branch eq, 0x9a
    expect_nzcv 0x6, 0x9a
    expect_reg_imm x8, 13, 0x9a

    /* 0x9b: adjacent CMN32 imm + plain ADC preserves 32-bit carry */
    mov     w5, #9
    mov     w6, #3
    movn    w0, #0            /* -1 */
    cmn     w0, #1
    adc     w8, w5, w6
    expect_branch eq, 0x9b
    expect_nzcv 0x6, 0x9b
    expect_reg_imm x8, 13, 0x9b

    /* 0x9c: adjacent ADDS64 imm rd + plain ADC preserves result and NZCV */
    movn    x0, #0            /* -1 */
    mov     x6, #9
    mov     x7, #3
    adds    x5, x0, #1
    adc     x8, x6, x7
    expect_branch eq, 0x9c
    expect_nzcv 0x6, 0x9c
    expect_reg_imm x5, 0, 0x9c
    expect_reg_imm x8, 13, 0x9c

    /* 0x9d: adjacent ADDS32 imm rd + plain ADC preserves 32-bit carry */
    movn    w0, #0            /* -1 */
    mov     w6, #9
    mov     w7, #3
    adds    w5, w0, #1
    adc     w8, w6, w7
    expect_branch eq, 0x9d
    expect_nzcv 0x6, 0x9d
    expect_reg_imm x5, 0, 0x9d
    expect_reg_imm x8, 13, 0x9d

    /* 0x9e: adjacent CMP64 imm + plain SBC preserves NZCV and result */
    mov     x5, #9
    mov     x6, #3
    cmp     x5, #9
    sbc     x8, x5, x6
    expect_branch eq, 0x9e
    expect_nzcv 0x6, 0x9e
    expect_reg_imm x8, 6, 0x9e

    /* 0x9f: adjacent CMP32 imm + plain SBC preserves 32-bit carry */
    mov     w5, #9
    mov     w6, #3
    cmp     w5, #9
    sbc     w8, w5, w6
    expect_branch eq, 0x9f
    expect_nzcv 0x6, 0x9f
    expect_reg_imm x8, 6, 0x9f

    /* 0xa0: adjacent SUBS64 imm rd + plain SBC preserves result and NZCV */
    mov     x0, #0
    mov     x6, #9
    mov     x7, #3
    subs    x5, x0, #1
    sbc     x8, x6, x7
    movn    x10, #0           /* -1 */
    expect_branch mi, 0xa0
    expect_nzcv 0x8, 0xa0
    expect_reg_reg x5, x10, 0xa0
    expect_reg_imm x8, 5, 0xa0

    /* 0xa1: adjacent SUBS32 imm rd + plain SBC preserves 32-bit borrow */
    mov     w0, #0
    mov     w6, #9
    mov     w7, #3
    subs    w5, w0, #1
    sbc     w8, w6, w7
    movn    w10, #0           /* 0xffffffff */
    expect_branch mi, 0xa1
    expect_nzcv 0x8, 0xa1
    expect_reg_reg x5, x10, 0xa1
    expect_reg_imm x8, 5, 0xa1

    /* 0xa2: adjacent CMN64 ext + plain ADC preserves NZCV and result */
    movn    x0, #0            /* -1 */
    mov     x1, #1
    mov     x5, #9
    mov     x6, #3
    cmn     x0, w1, uxtw #0
    adc     x8, x5, x6
    expect_branch eq, 0xa2
    expect_nzcv 0x6, 0xa2
    expect_reg_imm x8, 13, 0xa2

    /* 0xa3: adjacent CMN32 ext + plain ADC preserves 32-bit carry */
    movn    w0, #0            /* 0xffffffff */
    mov     w1, #1
    mov     w5, #9
    mov     w6, #3
    cmn     w0, w1, uxtw #0
    adc     w8, w5, w6
    expect_branch eq, 0xa3
    expect_nzcv 0x6, 0xa3
    expect_reg_imm x8, 13, 0xa3

    /* 0xa4: adjacent ADDS64 ext rd + plain ADC preserves result and NZCV */
    movn    x0, #0            /* -1 */
    mov     x1, #1
    mov     x6, #9
    mov     x7, #3
    adds    x5, x0, w1, uxtw #0
    adc     x8, x6, x7
    expect_branch eq, 0xa4
    expect_nzcv 0x6, 0xa4
    expect_reg_imm x5, 0, 0xa4
    expect_reg_imm x8, 13, 0xa4

    /* 0xa5: adjacent ADDS32 ext rd + plain ADC preserves 32-bit carry */
    movn    w0, #0            /* 0xffffffff */
    mov     w1, #1
    mov     w6, #9
    mov     w7, #3
    adds    w5, w0, w1, uxtw #0
    adc     w8, w6, w7
    expect_branch eq, 0xa5
    expect_nzcv 0x6, 0xa5
    expect_reg_imm x5, 0, 0xa5
    expect_reg_imm x8, 13, 0xa5

    /* 0xa6: adjacent CMP64 ext + plain SBC preserves NZCV and result */
    mov     x5, #9
    mov     x6, #3
    mov     x0, #4
    mov     w1, #2
    cmp     x0, w1, uxtw #1
    sbc     x8, x5, x6
    expect_branch eq, 0xa6
    expect_nzcv 0x6, 0xa6
    expect_reg_imm x8, 6, 0xa6

    /* 0xa7: adjacent CMP32 ext + plain SBC preserves 32-bit carry */
    mov     w5, #9
    mov     w6, #3
    mov     w0, #4
    mov     w1, #2
    cmp     w0, w1, uxtw #1
    sbc     w8, w5, w6
    expect_branch eq, 0xa7
    expect_nzcv 0x6, 0xa7
    expect_reg_imm x8, 6, 0xa7

    /* 0xa8: adjacent SUBS64 ext rd + plain SBC preserves result and NZCV */
    mov     x0, #0
    mov     x1, #1
    mov     x6, #9
    mov     x7, #3
    subs    x5, x0, w1, uxtw #0
    sbc     x8, x6, x7
    movn    x10, #0           /* -1 */
    expect_branch mi, 0xa8
    expect_nzcv 0x8, 0xa8
    expect_reg_reg x5, x10, 0xa8
    expect_reg_imm x8, 5, 0xa8

    /* 0xa9: adjacent SUBS32 ext rd + plain SBC preserves 32-bit borrow */
    mov     w0, #0
    mov     w1, #1
    mov     w6, #9
    mov     w7, #3
    subs    w5, w0, w1, uxtw #0
    sbc     w8, w6, w7
    movn    w10, #0           /* 0xffffffff */
    expect_branch mi, 0xa9
    expect_nzcv 0x8, 0xa9
    expect_reg_reg x5, x10, 0xa9
    expect_reg_imm x8, 5, 0xa9

    /* 0xaa: SUBS compare-like ext -> shared B.eq consumer TB */
    mov     x14, #1
    adr     x15, t_aa_after
    mov     x0, #4
    mov     w1, #2
    subs    xzr, x0, w1, uxtw #1
    b       shared_bcond_eq_consumer
t_aa_after:
    expect_reg_reg x2, x14, 0xaa
    expect_nzcv 0x6, 0xaa

    /* 0xab: ADCS raw producer -> ADC sees carry=1 (setflags consumer chain) */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    movn    x1, #0            /* -1 */
    mov     x2, #0
    adcs    xzr, x1, x2       /* Producer: -1+0+C=1=0, Z=1, C=1, V=0 -> NZCV=0x6 */
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6        /* Consumer: 10+20+1=31 */
    expect_nzcv 0x6, 0xab
    expect_reg_imm x7, 31, 0xab

    /* 0xac: SBCS raw producer -> ADC sees carry=0 (setflags consumer chain) */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    mov     x1, #1
    mov     x2, #3
    sbcs    xzr, x1, x2       /* Producer: 1-3-NOT(1)=-1, Z=0, C=0, V=0 -> NZCV=0x8 */
    mov     x5, #10
    mov     x6, #20
    adc     x7, x5, x6        /* Consumer: 10+20+0=30 */
    expect_nzcv 0x8, 0xac
    expect_reg_imm x7, 30, 0xac

    /* 0xad: ADCS32 raw producer -> ADC sees carry=1 (setflags consumer chain) */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    movn    w1, #0            /* 0xffffffff */
    mov     w2, #0
    adcs    w3, w1, w2        /* Producer: -1+0+1=0, Z=1, C=1, V=0 -> NZCV=0x6 */
    mov     w5, #10
    mov     w6, #20
    adc     w7, w5, w6         /* Consumer: 10+20+1=31 */
    expect_nzcv 0x6, 0xad
    expect_reg_imm w7, 31, 0xad

    /* 0xae: SBCS32 raw producer -> ADC sees carry=0 (setflags consumer chain) */
    mov     x0, #5
    cmp     x0, #3            /* Seed C = 1 */
    mov     w1, #1
    mov     w2, #3
    sbcs    w3, w1, w2        /* Producer: 1-3-NOT(1)=-1, Z=0, C=0, V=0 -> NZCV=0x8 */
    mov     w5, #10
    mov     w6, #20
    adc     w7, w5, w6         /* Consumer: 10+20+0=30 */
    expect_nzcv 0x8, 0xae
    expect_reg_imm w7, 30, 0xae

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
