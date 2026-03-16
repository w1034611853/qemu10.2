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
    b       after_shared_nzcv_consumer

shared_nzcv_consumer:
    mrs     x2, nzcv
    lsr     x2, x2, #28
    br      x15

after_shared_nzcv_consumer:

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
