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

_start:
    bl      adds_rd_fcsel_eq_gap1_case
    bl      adds_rd_fcsel_vs_gap4_case
    bl      adds_rd_fcsel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

adds_rd_fcsel_eq_gap1_case:
    movn    x0, #0
    mov     x1, #1
    fmov    d2, #2.0
    fmov    d3, #0.5
adds_rd_fcsel_eq_gap1_producer:
    adds    x5, x0, x1
    safe_gap_1
adds_rd_fcsel_eq_gap1_consumer:
    fcsel   d4, d2, d3, eq
    fmov    x6, d4
    ldr     x7, =0x4000000000000000
    cmp     x6, x7
    b.ne    fail
    cmp     x5, #0
    b.ne    fail
    ret

adds_rd_fcsel_vs_gap4_case:
    mov     x0, #1
    lsl     x0, x0, #63
    sub     x0, x0, #1
    mov     x1, #1
    fmov    d2, #2.0
    fmov    d3, #0.5
adds_rd_fcsel_vs_gap4_producer:
    adds    x5, x0, x1
    safe_gap_4
adds_rd_fcsel_vs_gap4_consumer:
    fcsel   d4, d2, d3, vs
    fmov    x6, d4
    ldr     x7, =0x4000000000000000
    cmp     x6, x7
    b.ne    fail
    ret

adds_rd_fcsel_bad_gap_case:
    movn    x0, #0
    mov     x1, #1
    fmov    d2, #2.0
    fmov    d3, #0.5
adds_rd_fcsel_bad_gap_producer:
    adds    x5, x0, x1
    adr     x9, adds_rd_fcsel_bad_gap_case
adds_rd_fcsel_bad_gap_consumer:
    fcsel   d4, d2, d3, eq
    fmov    x6, d4
    ldr     x7, =0x4000000000000000
    cmp     x6, x7
    b.ne    fail
    cmp     x5, #0
    b.ne    fail
    ret
