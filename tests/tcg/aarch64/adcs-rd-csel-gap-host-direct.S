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
    bl      adcs_rd_csel_eq_gap1_case
    bl      adcs_rd_csel_vs_gap4_case
    bl      adcs_rd_csel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

adcs_rd_csel_eq_gap1_case:
    movn    x0, #0
    mov     x1, #0
    mov     x3, #11
    mov     x4, #22
    cmp     xzr, xzr
adcs_rd_csel_eq_gap1_producer:
    adcs    x5, x0, x1
    safe_gap_1
adcs_rd_csel_eq_gap1_consumer:
    csel    x2, x3, x4, eq
    cmp     x5, #0
    b.ne    fail
    cmp     x2, #11
    b.ne    fail
    ret

adcs_rd_csel_vs_gap4_case:
    mov     x0, #1
    lsl     x0, x0, #63
    sub     x0, x0, #1
    mov     x1, #0
    mov     x3, #11
    mov     x4, #22
    cmp     xzr, xzr
adcs_rd_csel_vs_gap4_producer:
    adcs    x5, x0, x1
    safe_gap_4
adcs_rd_csel_vs_gap4_consumer:
    csel    x2, x3, x4, vs
    cmp     x2, #11
    b.ne    fail
    ret

adcs_rd_csel_bad_gap_case:
    movn    x0, #0
    mov     x1, #0
    mov     x3, #11
    mov     x4, #22
    cmp     xzr, xzr
adcs_rd_csel_bad_gap_producer:
    adcs    x5, x0, x1
    adr     x9, adcs_rd_csel_bad_gap_case
adcs_rd_csel_bad_gap_consumer:
    csel    x2, x3, x4, eq
    cmp     x5, #0
    b.ne    fail
    cmp     x2, #11
    b.ne    fail
    ret
