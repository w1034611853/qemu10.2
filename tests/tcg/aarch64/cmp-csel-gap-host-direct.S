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
    bl      cmp_csel_eq_gap1_case
    bl      cmp_csel_lt_gap4_case
    bl      cmp_csel_hi_gap8_case
    bl      cmp_csel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_csel_eq_gap1_case:
    mov     x0, #0x11
    mov     x1, #0x11
    mov     x3, #11
    mov     x4, #22
cmp_csel_eq_gap1_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csel_eq_gap1_consumer:
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret

cmp_csel_lt_gap4_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csel_lt_gap4_producer:
    cmp     x0, x1
    safe_gap_4
cmp_csel_lt_gap4_consumer:
    csel    x2, x3, x4, lt
    cmp     x2, #11
    b.ne    fail
    ret

cmp_csel_hi_gap8_case:
    mov     x0, #9
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csel_hi_gap8_producer:
    cmp     x0, x1
    safe_gap_8
cmp_csel_hi_gap8_consumer:
    csel    x2, x3, x4, hi
    cmp     x2, #11
    b.ne    fail
    ret

cmp_csel_bad_gap_case:
    mov     x0, #0x44
    mov     x1, #0x44
    mov     x3, #11
    mov     x4, #22
cmp_csel_bad_gap_producer:
    cmp     x0, x1
    adr     x9, cmp_csel_bad_gap_case
cmp_csel_bad_gap_consumer:
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret
