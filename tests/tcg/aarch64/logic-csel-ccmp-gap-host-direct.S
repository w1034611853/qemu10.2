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
    bl      tst_csel_eq_gap1_case
    bl      ands_csel_mi_gap4_case
    bl      tst_ccmp_true_gap1_case
    bl      ands_ccmp_false_gap4_case
    bl      tst_csel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

tst_csel_eq_gap1_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
    tst     x0, x1
    safe_gap_1
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret

ands_csel_mi_gap4_case:
    mov     x0, #1
    lsl     x0, x0, #63
    movn    x1, #0
    mov     x3, #11
    mov     x4, #22
    ands    xzr, x0, x1
    safe_gap_4
    csel    x2, x3, x4, mi
    cmp     x2, #11
    b.ne    fail
    ret

tst_ccmp_true_gap1_case:
    mov     x0, #3
    mov     x1, #1
    mov     x3, #4
    mov     x4, #4
    tst     x0, x1
    safe_gap_1
    ccmp    x3, x4, #0xa, ne
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x5, #6
    b.ne    fail
    ret

ands_ccmp_false_gap4_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #4
    mov     x4, #4
    ands    xzr, x0, x1
    safe_gap_4
    ccmp    x3, x4, #0xa, ne
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x5, #0xa
    b.ne    fail
    ret

tst_csel_bad_gap_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
    tst     x0, x1
    adr     x9, tst_csel_bad_gap_case
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret
