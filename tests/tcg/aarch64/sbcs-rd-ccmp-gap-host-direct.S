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
    bl      sbcs_rd_ccmp_true_gap1_case
    bl      sbcs_rd_ccmp_false_gap4_case
    bl      sbcs_rd_ccmp_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

sbcs_rd_ccmp_true_gap1_case:
    mov     x0, #9
    mov     x1, #3
    mov     x2, #4
    mov     x3, #4
    cmp     xzr, xzr
sbcs_rd_ccmp_true_gap1_producer:
    sbcs    x5, x0, x1
    safe_gap_1
sbcs_rd_ccmp_true_gap1_consumer:
    ccmp    x2, x3, #0xa, cs
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    cmp     x5, #6
    b.ne    fail
    ret

sbcs_rd_ccmp_false_gap4_case:
    mov     x0, #1
    mov     x1, #3
    mov     x2, #4
    mov     x3, #4
    cmp     xzr, xzr
sbcs_rd_ccmp_false_gap4_producer:
    sbcs    x5, x0, x1
    safe_gap_4
sbcs_rd_ccmp_false_gap4_consumer:
    ccmp    x2, x3, #0xa, cs
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #0xa
    b.ne    fail
    mov     x7, #-2
    cmp     x5, x7
    b.ne    fail
    ret

sbcs_rd_ccmp_bad_gap_case:
    mov     x0, #9
    mov     x1, #3
    mov     x2, #4
    mov     x3, #4
    cmp     xzr, xzr
sbcs_rd_ccmp_bad_gap_producer:
    sbcs    x5, x0, x1
    adr     x9, sbcs_rd_ccmp_bad_gap_case
sbcs_rd_ccmp_bad_gap_consumer:
    ccmp    x2, x3, #0xa, cs
    mrs     x6, nzcv
    lsr     x6, x6, #28
    cmp     x6, #6
    b.ne    fail
    cmp     x5, #6
    b.ne    fail
    ret
