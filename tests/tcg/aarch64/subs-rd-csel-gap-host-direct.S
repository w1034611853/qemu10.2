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
    bl      subs_rd_csel_eq_gap1_case
    bl      subs_rd_csel_lt_gap4_case
    bl      subs_rd_csinc_eq_gap1_case
    bl      subs_rd_csinv_eq_gap4_case
    bl      subs_rd_csneg_eq_gap8_case
    bl      subs_rd_cset_eq_gap1_case
    bl      subs_rd_csetm_hi_gap4_case
    bl      subs_rd_csel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

subs_rd_csel_eq_gap1_case:
    mov     x0, #5
    mov     x1, #5
    mov     x3, #11
    mov     x4, #22
subs_rd_csel_eq_gap1_producer:
    subs    x5, x0, x1
    safe_gap_1
subs_rd_csel_eq_gap1_consumer:
    csel    x2, x3, x4, eq
    cmp     x5, #0
    b.ne    fail
    cmp     x2, #11
    b.ne    fail
    ret

subs_rd_csel_lt_gap4_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
subs_rd_csel_lt_gap4_producer:
    subs    x5, x0, x1
    safe_gap_4
subs_rd_csel_lt_gap4_consumer:
    csel    x2, x3, x4, lt
    mov     x6, #-2
    cmp     x5, x6
    b.ne    fail
    cmp     x2, #11
    b.ne    fail
    ret

subs_rd_csinc_eq_gap1_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
subs_rd_csinc_eq_gap1_producer:
    subs    x5, x0, x1
    safe_gap_1
subs_rd_csinc_eq_gap1_consumer:
    csinc   x2, x3, x4, eq
    cmp     x2, #23
    b.ne    fail
    ret

subs_rd_csinv_eq_gap4_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
subs_rd_csinv_eq_gap4_producer:
    subs    x5, x0, x1
    safe_gap_4
subs_rd_csinv_eq_gap4_consumer:
    csinv   x2, x3, x4, eq
    mov     x6, #-23
    cmp     x2, x6
    b.ne    fail
    ret

subs_rd_csneg_eq_gap8_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
subs_rd_csneg_eq_gap8_producer:
    subs    x5, x0, x1
    safe_gap_8
subs_rd_csneg_eq_gap8_consumer:
    csneg   x2, x3, x4, eq
    mov     x6, #-22
    cmp     x2, x6
    b.ne    fail
    ret

subs_rd_cset_eq_gap1_case:
    mov     x0, #5
    mov     x1, #5
subs_rd_cset_eq_gap1_producer:
    subs    x5, x0, x1
    safe_gap_1
subs_rd_cset_eq_gap1_consumer:
    cset    x2, eq
    cmp     x5, #0
    b.ne    fail
    cmp     x2, #1
    b.ne    fail
    ret

subs_rd_csetm_hi_gap4_case:
    mov     x0, #9
    mov     x1, #3
subs_rd_csetm_hi_gap4_producer:
    subs    x5, x0, x1
    safe_gap_4
subs_rd_csetm_hi_gap4_consumer:
    csetm   x2, hi
    mov     x6, #-1
    cmp     x2, x6
    b.ne    fail
    ret

subs_rd_csel_bad_gap_case:
    mov     x0, #5
    mov     x1, #5
    mov     x3, #11
    mov     x4, #22
subs_rd_csel_bad_gap_producer:
    subs    x5, x0, x1
    adr     x9, subs_rd_csel_bad_gap_case
subs_rd_csel_bad_gap_consumer:
    csel    x2, x3, x4, eq
    cmp     x5, #0
    b.ne    fail
    cmp     x2, #11
    b.ne    fail
    ret
