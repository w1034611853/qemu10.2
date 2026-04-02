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
    bl      cmp_fccmp_true_gap1_case
    bl      cmp_fccmp_false_gap4_case
    bl      cmp_fccmp_true_gap8_case
    bl      cmp_fccmp_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_fccmp_true_gap1_case:
    mov     x0, #1
    fmov    d0, #1.0
    fmov    d1, #1.0
cmp_fccmp_true_gap1_producer:
    cmp     x0, #1
    safe_gap_1
cmp_fccmp_true_gap1_consumer:
    fccmp   d0, d1, #0xa, eq
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #6
    b.ne    fail
    ret

cmp_fccmp_false_gap4_case:
    mov     x0, #1
    fmov    d0, #1.0
    fmov    d1, #2.0
cmp_fccmp_false_gap4_producer:
    cmp     x0, #2
    safe_gap_4
cmp_fccmp_false_gap4_consumer:
    fccmp   d0, d1, #0xa, eq
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #0xa
    b.ne    fail
    ret

cmp_fccmp_true_gap8_case:
    mov     x0, #2
    fmov    d0, #1.0
    fmov    d1, #1.0
cmp_fccmp_true_gap8_producer:
    cmp     x0, #1
    safe_gap_8
cmp_fccmp_true_gap8_consumer:
    fccmp   d0, d1, #0xa, gt
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #6
    b.ne    fail
    ret

cmp_fccmp_bad_gap_case:
    mov     x0, #1
    fmov    d0, #1.0
    fmov    d1, #1.0
cmp_fccmp_bad_gap_producer:
    cmp     x0, #1
    adr     x9, cmp_fccmp_bad_gap_case
cmp_fccmp_bad_gap_consumer:
    fccmp   d0, d1, #0xa, eq
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #6
    b.ne    fail
    ret
