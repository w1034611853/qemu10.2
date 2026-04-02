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
    bl      cmp_ccmp_true_gap1_case
    bl      cmp_ccmp_false_gap4_case
    bl      cmp_ccmn_true_gap8_case
    bl      cmp_ccmp_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_ccmp_true_gap1_case:
    mov     x1, #4
    mov     x2, #4
    mov     x0, #9
cmp_ccmp_true_gap1_producer:
    cmp     x0, #9
    safe_gap_1
cmp_ccmp_true_gap1_consumer:
    ccmp    x1, x2, #0xa, eq
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #6
    b.ne    fail
    ret

cmp_ccmp_false_gap4_case:
    mov     x1, #4
    mov     x2, #4
    mov     x0, #1
cmp_ccmp_false_gap4_producer:
    cmp     x0, #2
    safe_gap_4
cmp_ccmp_false_gap4_consumer:
    ccmp    x1, x2, #0xa, eq
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #0xa
    b.ne    fail
    ret

cmp_ccmn_true_gap8_case:
    movn    x1, #0
    mov     x2, #1
    mov     x0, #1
cmp_ccmn_true_gap8_producer:
    cmp     x0, #1
    safe_gap_8
cmp_ccmn_true_gap8_consumer:
    ccmn    x1, x2, #0xa, eq
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #6
    b.ne    fail
    ret

cmp_ccmp_bad_gap_case:
    mov     x1, #4
    mov     x2, #4
    mov     x0, #9
cmp_ccmp_bad_gap_producer:
    cmp     x0, #9
    adr     x9, cmp_ccmp_bad_gap_case
cmp_ccmp_bad_gap_consumer:
    ccmp    x1, x2, #0xa, eq
    mrs     x3, nzcv
    lsr     x3, x3, #28
    cmp     x3, #6
    b.ne    fail
    ret
