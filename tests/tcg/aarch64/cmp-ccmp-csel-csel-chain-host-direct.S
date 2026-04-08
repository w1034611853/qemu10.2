    .text
    .global _start

    .macro safe_gap_1
    nop
    .endm

_start:
    bl      cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_case
    bl      cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_case
    bl      cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_case
    bl      cmp_ccmp_eq_csel_eq_csel_eq_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_case:
    mov     x0, #7
    mov     x1, #7
    mov     x20, #5
    mov     x3, #11
    mov     x4, #22
    mov     x5, #33
    mov     x6, #44
cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_ccmp:
    ccmp    x20, #5, #0xa, eq
cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_first_csel:
    csel    x2, x3, x4, eq
cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_second_csel:
    csel    x7, x5, x6, eq
cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_branch:
    b.eq    cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_taken
    b       fail
cmp_ccmp_eq_csel_eq_csel_eq_bcond_eq_chain_taken:
    cmp     x2, #11
    b.ne    fail
    cmp     x7, #33
    b.ne    fail
    ret

cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_case:
    mov     x0, #7
    mov     x1, #8
    mov     x20, #5
    mov     x5, #19
    mov     x6, #30
cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_ccmp:
    ccmp    x20, #5, #0x8, eq
cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_first_csel:
    csetm   x2, mi
cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_second_csel:
    csinc   x7, x5, x6, mi
cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_branch:
    b.mi    cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_taken
    b       fail
cmp_ccmp_false_lit_mi_csetm_mi_csinc_mi_bcond_mi_chain_taken:
    movn    x3, #0
    cmp     x2, x3
    b.ne    fail
    cmp     x7, #19
    b.ne    fail
    ret

cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_case:
    mov     x0, #9
    mov     x1, #3
    movn    x20, #0
    mov     x21, #1
    mov     x3, #11
    mov     x4, #22
cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_ccmp:
    ccmn    x20, x21, #0, hi
cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_first_csel:
    csinc   x2, x3, x4, eq
cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_second_csel:
    cset    x7, eq
cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_branch:
    b.eq    cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_taken
    b       fail
cmp_ccmn_hi_csinc_eq_cset_eq_bcond_eq_chain_taken:
    cmp     x2, #11
    b.ne    fail
    cmp     x7, #1
    b.ne    fail
    ret

cmp_ccmp_eq_csel_eq_csel_eq_gap_case:
    mov     x0, #5
    mov     x1, #5
    mov     x20, #9
    mov     x3, #55
    mov     x4, #66
    mov     x5, #77
    mov     x6, #88
cmp_ccmp_eq_csel_eq_csel_eq_gap_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmp_eq_csel_eq_csel_eq_gap_ccmp:
    ccmp    x20, #9, #0xa, eq
cmp_ccmp_eq_csel_eq_csel_eq_gap_first_csel:
    csel    x2, x3, x4, eq
cmp_ccmp_eq_csel_eq_csel_eq_gap_blocker:
    nop
cmp_ccmp_eq_csel_eq_csel_eq_gap_second_csel:
    csel    x7, x5, x6, eq
cmp_ccmp_eq_csel_eq_csel_eq_gap_branch:
    b.eq    cmp_ccmp_eq_csel_eq_csel_eq_gap_taken
    b       fail
cmp_ccmp_eq_csel_eq_csel_eq_gap_taken:
    cmp     x2, #55
    b.ne    fail
    cmp     x7, #77
    b.ne    fail
    ret
