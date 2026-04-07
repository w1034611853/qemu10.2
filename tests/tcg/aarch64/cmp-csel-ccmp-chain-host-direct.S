    .text
    .global _start

    .macro safe_gap_1
    nop
    .endm

_start:
    bl      cmp_csel_eq_ccmp_eq_chain_case
    bl      cmp32_cset_ne_ccmp_ne_chain_case
    bl      cmp_csinc_hi_ccmn_hi_chain_case
    bl      cmp_csel_eq_ccmp_eq_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_csel_eq_ccmp_eq_chain_case:
    mov     x0, #7
    mov     x1, #7
    mov     x3, #11
    mov     x4, #22
    mov     x20, #5
cmp_csel_eq_ccmp_eq_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csel_eq_ccmp_eq_chain_csel:
    csel    x2, x3, x4, eq
cmp_csel_eq_ccmp_eq_chain_ccmp:
    ccmp    x20, #5, #0xa, eq
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x2, #11
    b.ne    fail
    cmp     x5, #6
    b.ne    fail
    ret

cmp32_cset_ne_ccmp_ne_chain_case:
    mov     w0, #1
    mov     w1, #3
    mov     w20, #10
cmp32_cset_ne_ccmp_ne_chain_producer:
    cmp     w0, w1
    safe_gap_1
cmp32_cset_ne_ccmp_ne_chain_csel:
    cset    w2, ne
cmp32_cset_ne_ccmp_ne_chain_ccmp:
    ccmp    w20, #10, #0, ne
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     w2, #1
    b.ne    fail
    cmp     x5, #6
    b.ne    fail
    ret

cmp_csinc_hi_ccmn_hi_chain_case:
    mov     x0, #9
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
    movn    x20, #0
    mov     x21, #1
cmp_csinc_hi_ccmn_hi_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csinc_hi_ccmn_hi_chain_csel:
    csinc   x2, x3, x4, hi
cmp_csinc_hi_ccmn_hi_chain_ccmp:
    ccmn    x20, x21, #0xa, hi
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x2, #11
    b.ne    fail
    cmp     x5, #6
    b.ne    fail
    ret

cmp_csel_eq_ccmp_eq_gap_case:
    mov     x0, #5
    mov     x1, #5
    mov     x3, #33
    mov     x4, #44
    mov     x20, #5
cmp_csel_eq_ccmp_eq_gap_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csel_eq_ccmp_eq_gap_csel:
    csel    x2, x3, x4, eq
cmp_csel_eq_ccmp_eq_gap_blocker:
    nop
cmp_csel_eq_ccmp_eq_gap_ccmp:
    ccmp    x20, #5, #0xa, eq
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x2, #33
    b.ne    fail
    cmp     x5, #6
    b.ne    fail
    ret
