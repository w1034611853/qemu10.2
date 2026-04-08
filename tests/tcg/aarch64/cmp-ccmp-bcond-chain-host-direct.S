    .text
    .global _start

    .macro safe_gap_1
    nop
    .endm

_start:
    bl      cmp_ccmp_eq_bcond_eq_chain_case
    bl      cmp_ccmp_false_lit_mi_bcond_mi_chain_case
    bl      cmp_ccmn_hi_bcond_eq_chain_case
    bl      cmp_ccmp_eq_bcond_eq_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_ccmp_eq_bcond_eq_chain_case:
    mov     x0, #7
    mov     x1, #7
    mov     x20, #5
cmp_ccmp_eq_bcond_eq_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmp_eq_bcond_eq_chain_ccmp:
    ccmp    x20, #5, #0xa, eq
cmp_ccmp_eq_bcond_eq_chain_branch:
    b.eq    cmp_ccmp_eq_bcond_eq_chain_taken
    b       fail
cmp_ccmp_eq_bcond_eq_chain_taken:
    ret

cmp_ccmp_false_lit_mi_bcond_mi_chain_case:
    mov     x0, #7
    mov     x1, #8
    mov     x20, #5
cmp_ccmp_false_lit_mi_bcond_mi_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmp_false_lit_mi_bcond_mi_chain_ccmp:
    ccmp    x20, #5, #0x8, eq
cmp_ccmp_false_lit_mi_bcond_mi_chain_branch:
    b.mi    cmp_ccmp_false_lit_mi_bcond_mi_chain_taken
    b       fail
cmp_ccmp_false_lit_mi_bcond_mi_chain_taken:
    ret

cmp_ccmn_hi_bcond_eq_chain_case:
    mov     x0, #9
    mov     x1, #3
    movn    x20, #0
    mov     x21, #1
cmp_ccmn_hi_bcond_eq_chain_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmn_hi_bcond_eq_chain_ccmp:
    ccmn    x20, x21, #0, hi
cmp_ccmn_hi_bcond_eq_chain_branch:
    b.eq    cmp_ccmn_hi_bcond_eq_chain_taken
    b       fail
cmp_ccmn_hi_bcond_eq_chain_taken:
    ret

cmp_ccmp_eq_bcond_eq_gap_case:
    mov     x0, #5
    mov     x1, #5
    mov     x20, #9
cmp_ccmp_eq_bcond_eq_gap_producer:
    cmp     x0, x1
    safe_gap_1
cmp_ccmp_eq_bcond_eq_gap_ccmp:
    ccmp    x20, #9, #0xa, eq
cmp_ccmp_eq_bcond_eq_gap_blocker:
    nop
cmp_ccmp_eq_bcond_eq_gap_branch:
    b.eq    cmp_ccmp_eq_bcond_eq_gap_taken
    b       fail
cmp_ccmp_eq_bcond_eq_gap_taken:
    ret
