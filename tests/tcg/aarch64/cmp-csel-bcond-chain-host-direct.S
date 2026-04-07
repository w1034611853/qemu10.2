    .text
    .global _start

    .macro safe_gap_1
    nop
    .endm

_start:
    bl      cmp_csel_eq_bcond_eq_chain_case
    bl      cmp32_cset_ne_bcond_ne_chain_case
    bl      cmp_csinc_hi_bcond_hi_chain_case
    bl      cmp_csel_eq_bcond_eq_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_csel_eq_bcond_eq_chain_case:
    mov     x0, #7
    mov     x1, #7
    mov     x3, #11
    mov     x4, #22
cmp_csel_eq_bcond_eq_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csel_eq_bcond_eq_chain_csel:
    csel    x2, x3, x4, eq
cmp_csel_eq_bcond_eq_chain_branch:
    b.eq    cmp_csel_eq_bcond_eq_chain_taken
    b       fail
cmp_csel_eq_bcond_eq_chain_taken:
    cmp     x2, #11
    b.ne    fail
    ret

cmp32_cset_ne_bcond_ne_chain_case:
    mov     w0, #1
    mov     w1, #3
cmp32_cset_ne_bcond_ne_chain_producer:
    cmp     w0, w1
    safe_gap_1
cmp32_cset_ne_bcond_ne_chain_csel:
    cset    w2, ne
cmp32_cset_ne_bcond_ne_chain_branch:
    b.ne    cmp32_cset_ne_bcond_ne_chain_taken
    b       fail
cmp32_cset_ne_bcond_ne_chain_taken:
    cmp     w2, #1
    b.ne    fail
    ret

cmp_csinc_hi_bcond_hi_chain_case:
    mov     x0, #9
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csinc_hi_bcond_hi_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csinc_hi_bcond_hi_chain_csel:
    csinc   x2, x3, x4, hi
cmp_csinc_hi_bcond_hi_chain_branch:
    b.hi    cmp_csinc_hi_bcond_hi_chain_taken
    b       fail
cmp_csinc_hi_bcond_hi_chain_taken:
    cmp     x2, #11
    b.ne    fail
    ret

cmp_csel_eq_bcond_eq_gap_case:
    mov     x0, #5
    mov     x1, #5
    mov     x3, #33
    mov     x4, #44
cmp_csel_eq_bcond_eq_gap_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csel_eq_bcond_eq_gap_csel:
    csel    x2, x3, x4, eq
cmp_csel_eq_bcond_eq_gap_blocker:
    nop
cmp_csel_eq_bcond_eq_gap_branch:
    b.eq    cmp_csel_eq_bcond_eq_gap_taken
    b       fail
cmp_csel_eq_bcond_eq_gap_taken:
    cmp     x2, #33
    b.ne    fail
    ret
