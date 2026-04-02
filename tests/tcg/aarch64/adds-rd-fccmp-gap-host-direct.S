    .text
    .global _start

    .macro safe_gap_1
    nop
    .endm

    .macro safe_gap_4
    nop
    movz    x9, #0x11
    add     x10, x10, #1
    ubfx    x11, x11, #0, #8
    .endm

    .macro safe_gap_8
    nop
    movz    x9, #0x22
    movk    x9, #0x33, lsl #16
    add     x10, x10, #1
    sub     x11, x11, #1
    orr     x12, x12, xzr
    ubfx    x13, x13, #0, #8
    add     x14, x14, xzr
    .endm

_start:
    bl      adds_rd_fccmp_true_gap1_case
    bl      adds_rd_fccmp_false_gap4_case
    bl      adds_rd_fccmp_true_gap8_case
    bl      adds_rd_fccmp_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

adds_rd_fccmp_true_gap1_case:
    movn    x0, #0
    mov     x1, #1
    fmov    d0, #1.0
    fmov    d1, #1.0
adds_rd_fccmp_true_gap1_producer:
    adds    x5, x0, x1
    safe_gap_1
adds_rd_fccmp_true_gap1_consumer:
    fccmp   d0, d1, #0xa, eq
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    cmp     x5, #0
    b.ne    fail
    ret

adds_rd_fccmp_false_gap4_case:
    mov     x0, #1
    mov     x1, #2
    fmov    d0, #1.0
    fmov    d1, #2.0
adds_rd_fccmp_false_gap4_producer:
    adds    x5, x0, x1
    safe_gap_4
adds_rd_fccmp_false_gap4_consumer:
    fccmp   d0, d1, #0xa, eq
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #0xa
    b.ne    fail
    cmp     x5, #3
    b.ne    fail
    ret

adds_rd_fccmp_true_gap8_case:
    mov     x0, #1
    lsl     x0, x0, #63
    sub     x0, x0, #1
    mov     x1, #1
    fmov    d0, #1.0
    fmov    d1, #1.0
adds_rd_fccmp_true_gap8_producer:
    adds    x5, x0, x1
    safe_gap_8
adds_rd_fccmp_true_gap8_consumer:
    fccmp   d0, d1, #0xa, vs
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    ret

adds_rd_fccmp_bad_gap_case:
    movn    x0, #0
    mov     x1, #1
    fmov    d0, #1.0
    fmov    d1, #1.0
adds_rd_fccmp_bad_gap_producer:
    adds    x5, x0, x1
    adr     x9, adds_rd_fccmp_bad_gap_case
adds_rd_fccmp_bad_gap_consumer:
    fccmp   d0, d1, #0xa, eq
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    cmp     x5, #0
    b.ne    fail
    ret
