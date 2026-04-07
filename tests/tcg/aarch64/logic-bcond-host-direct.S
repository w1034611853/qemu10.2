    .text
    .global _start

_start:
    bl      tst_eq_adj_case
    bl      ands_mi_adj_case
    bl      tst_gt_adj_case
    bl      tst32_mi_adj_case
    bl      tst_eq_gap_case
    bl      tst_vs_adj_case
    bl      tst_cc_adj_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

tst_eq_adj_case:
    mov     x0, #3
    mov     x1, #4
tst_eq_adj_producer:
    tst     x0, x1
tst_eq_adj_branch:
    b.eq    tst_eq_adj_taken
    b       fail
tst_eq_adj_taken:
    ret

ands_mi_adj_case:
    mov     x0, #1
    lsl     x0, x0, #63
    movn    x1, #0
ands_mi_adj_producer:
    ands    xzr, x0, x1
ands_mi_adj_branch:
    b.mi    ands_mi_adj_taken
    b       fail
ands_mi_adj_taken:
    ret

tst_gt_adj_case:
    mov     x0, #7
    mov     x1, #3
tst_gt_adj_producer:
    tst     x0, x1
tst_gt_adj_branch:
    b.gt    tst_gt_adj_taken
    b       fail
tst_gt_adj_taken:
    ret

tst32_mi_adj_case:
    mov     w0, #1
    lsl     w0, w0, #31
    movn    w1, #0
tst32_mi_adj_producer:
    tst     w0, w1
tst32_mi_adj_branch:
    b.mi    tst32_mi_adj_taken
    b       fail
tst32_mi_adj_taken:
    ret

tst_eq_gap_case:
    mov     x0, #3
    mov     x1, #4
tst_eq_gap_producer:
    tst     x0, x1
    nop
tst_eq_gap_branch:
    b.eq    tst_eq_gap_taken
    b       fail
tst_eq_gap_taken:
    ret

tst_vs_adj_case:
    mov     x0, #3
    mov     x1, #1
tst_vs_adj_producer:
    tst     x0, x1
tst_vs_adj_branch:
    b.vs    fail
    ret

tst_cc_adj_case:
    mov     x0, #3
    mov     x1, #1
tst_cc_adj_producer:
    tst     x0, x1
tst_cc_adj_branch:
    b.cc    tst_cc_adj_taken
    b       fail
tst_cc_adj_taken:
    ret
