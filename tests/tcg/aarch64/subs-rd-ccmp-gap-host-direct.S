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
    bl      subs_rd_ccmp_true_gap1_case
    bl      subs_rd_ccmp_false_gap4_case
    bl      subs_rd_ccmn_true_gap8_case
    bl      subs_rd_ccmp_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

subs_rd_ccmp_true_gap1_case:
    mov     x0, #9
    mov     x1, #9
    mov     x2, #4
    mov     x3, #4
subs_rd_ccmp_true_gap1_producer:
    subs    x5, x0, x1
    safe_gap_1
subs_rd_ccmp_true_gap1_consumer:
    ccmp    x2, x3, #0xa, eq
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    cmp     x5, #0
    b.ne    fail
    ret

subs_rd_ccmp_false_gap4_case:
    mov     x0, #9
    mov     x1, #5
    mov     x2, #4
    mov     x3, #4
subs_rd_ccmp_false_gap4_producer:
    subs    x5, x0, x1
    safe_gap_4
subs_rd_ccmp_false_gap4_consumer:
    ccmp    x2, x3, #0xa, eq
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #0xa
    b.ne    fail
    cmp     x5, #4
    b.ne    fail
    ret

subs_rd_ccmn_true_gap8_case:
    mov     x0, #9
    mov     x1, #9
    movn    x2, #0
    mov     x3, #1
subs_rd_ccmn_true_gap8_producer:
    subs    x5, x0, x1
    safe_gap_8
subs_rd_ccmn_true_gap8_consumer:
    ccmn    x2, x3, #0xa, eq
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    cmp     x5, #0
    b.ne    fail
    ret

subs_rd_ccmp_bad_gap_case:
    mov     x0, #9
    mov     x1, #9
    mov     x2, #4
    mov     x3, #4
subs_rd_ccmp_bad_gap_producer:
    subs    x5, x0, x1
    adr     x9, subs_rd_ccmp_bad_gap_case
subs_rd_ccmp_bad_gap_consumer:
    ccmp    x2, x3, #0xa, eq
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    cmp     x5, #0
    b.ne    fail
    ret
