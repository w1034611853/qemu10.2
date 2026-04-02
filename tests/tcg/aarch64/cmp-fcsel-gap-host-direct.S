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
    bl      cmp_fcsel_eq_gap1_case
    bl      cmp_fcsel_lt_gap4_case
    bl      cmp_fcsel_hi_gap8_case
    bl      cmp_fcsel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_fcsel_eq_gap1_case:
    mov     x0, #3
    cmp     x0, #3
    fmov    d2, #2.0
    fmov    d3, #0.5
cmp_fcsel_eq_gap1_producer:
    cmp     x0, #3
    safe_gap_1
cmp_fcsel_eq_gap1_consumer:
    fcsel   d4, d2, d3, eq
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    cmp     x5, x6
    b.ne    fail
    ret

cmp_fcsel_lt_gap4_case:
    mov     x0, #1
    cmp     x0, #3
    fmov    d2, #2.0
    fmov    d3, #0.5
cmp_fcsel_lt_gap4_producer:
    cmp     x0, #3
    safe_gap_4
cmp_fcsel_lt_gap4_consumer:
    fcsel   d4, d2, d3, lt
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    cmp     x5, x6
    b.ne    fail
    ret

cmp_fcsel_hi_gap8_case:
    mov     x0, #9
    cmp     x0, #3
    fmov    d2, #2.0
    fmov    d3, #0.5
cmp_fcsel_hi_gap8_producer:
    cmp     x0, #3
    safe_gap_8
cmp_fcsel_hi_gap8_consumer:
    fcsel   d4, d2, d3, hi
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    cmp     x5, x6
    b.ne    fail
    ret

cmp_fcsel_bad_gap_case:
    mov     x0, #3
    cmp     x0, #3
    fmov    d2, #2.0
    fmov    d3, #0.5
cmp_fcsel_bad_gap_producer:
    cmp     x0, #3
    adr     x9, cmp_fcsel_bad_gap_case
cmp_fcsel_bad_gap_consumer:
    fcsel   d4, d2, d3, eq
    fmov    x5, d4
    ldr     x6, =0x4000000000000000
    cmp     x5, x6
    b.ne    fail
    ret
