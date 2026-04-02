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
    bl      sbcs_rd_csel_cs_gap1_case
    bl      sbcs_rd_csel_mi_gap4_case
    bl      sbcs_rd_csel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

sbcs_rd_csel_cs_gap1_case:
    mov     x0, #9
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
    cmp     xzr, xzr
sbcs_rd_csel_cs_gap1_producer:
    sbcs    x5, x0, x1
    safe_gap_1
sbcs_rd_csel_cs_gap1_consumer:
    csel    x2, x3, x4, cs
    cmp     x5, #6
    b.ne    fail
    cmp     x2, #11
    b.ne    fail
    ret

sbcs_rd_csel_mi_gap4_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
    cmp     xzr, xzr
sbcs_rd_csel_mi_gap4_producer:
    sbcs    x5, x0, x1
    safe_gap_4
sbcs_rd_csel_mi_gap4_consumer:
    csel    x2, x3, x4, mi
    cmp     x2, #11
    b.ne    fail
    mov     x6, #-2
    cmp     x5, x6
    b.ne    fail
    ret

sbcs_rd_csel_bad_gap_case:
    mov     x0, #9
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
    cmp     xzr, xzr
sbcs_rd_csel_bad_gap_producer:
    sbcs    x5, x0, x1
    adr     x9, sbcs_rd_csel_bad_gap_case
sbcs_rd_csel_bad_gap_consumer:
    csel    x2, x3, x4, cs
    cmp     x5, #6
    b.ne    fail
    cmp     x2, #11
    b.ne    fail
    ret
