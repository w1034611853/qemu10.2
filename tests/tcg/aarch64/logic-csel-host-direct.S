    .text
    .global _start

_start:
    bl      tst_csel_eq_adj_case
    bl      tst_csel_eq_adj_rd_rn_case
    bl      ands_csinv_mi_adj_case
    bl      tst_cset_eq_adj_case
    bl      tst_cset_eq_false_adj_case
    bl      tst_csetm_eq_adj_case
    bl      tst_csetm_eq_false_adj_case
    bl      tst_csel_cc_adj_case
    bl      tst_csel_eq_gap_case
    bl      tst_csel_eq_adj_rm_zr_false_case
    bl      tst_csel_eq_adj_rn_zr_false_case
    bl      tst_csinc_adj_case
    bl      tst_csinc_adj_rd_rn_case
    bl      tst_csneg_adj_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

tst_csel_eq_adj_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
tst_csel_eq_adj_producer:
    tst     x0, x1
tst_csel_eq_adj_consumer:
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret

tst_csel_eq_adj_rd_rn_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
tst_csel_eq_adj_rd_rn_producer:
    tst     x0, x1
tst_csel_eq_adj_rd_rn_consumer:
    csel    x3, x3, x4, eq
    cmp     x3, #11
    b.ne    fail
    ret

ands_csinv_mi_adj_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
ands_csinv_mi_adj_producer:
    ands    xzr, x0, x1
ands_csinv_mi_adj_consumer:
    csinv   x2, x3, x4, mi
    movn    x5, #22
    cmp     x2, x5
    b.ne    fail
    ret

tst_cset_eq_adj_case:
    mov     x0, #3
    mov     x1, #4
tst_cset_eq_adj_producer:
    tst     x0, x1
tst_cset_eq_adj_consumer:
    cset    x2, eq
    cmp     x2, #1
    b.ne    fail
    ret

tst_cset_eq_false_adj_case:
    mov     x0, #3
    mov     x1, #1
tst_cset_eq_false_adj_producer:
    tst     x0, x1
tst_cset_eq_false_adj_consumer:
    cset    x2, eq
    cmp     x2, #0
    b.ne    fail
    ret

tst_csetm_eq_adj_case:
    mov     x0, #3
    mov     x1, #4
tst_csetm_eq_adj_producer:
    tst     x0, x1
tst_csetm_eq_adj_consumer:
    csetm   x2, eq
    movn    x5, #0
    cmp     x2, x5
    b.ne    fail
    ret

tst_csetm_eq_false_adj_case:
    mov     x0, #3
    mov     x1, #1
tst_csetm_eq_false_adj_producer:
    tst     x0, x1
tst_csetm_eq_false_adj_consumer:
    csetm   x2, eq
    cmp     x2, #0
    b.ne    fail
    ret

tst_csel_cc_adj_case:
    mov     x0, #3
    mov     x1, #1
    mov     x3, #11
    mov     x4, #22
tst_csel_cc_adj_producer:
    tst     x0, x1
tst_csel_cc_adj_consumer:
    csel    x2, x3, x4, cc
    cmp     x2, #11
    b.ne    fail
    ret

tst_csel_eq_gap_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
tst_csel_eq_gap_producer:
    tst     x0, x1
    nop
tst_csel_eq_gap_consumer:
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret

tst_csel_eq_adj_rm_zr_false_case:
    mov     x0, #3
    mov     x1, #1
    mov     x3, #11
tst_csel_eq_adj_rm_zr_false_producer:
    tst     x0, x1
tst_csel_eq_adj_rm_zr_false_consumer:
    csel    x2, x3, xzr, eq
    cmp     x2, #0
    b.ne    fail
    ret

tst_csel_eq_adj_rn_zr_false_case:
    mov     x0, #3
    mov     x1, #1
    mov     x4, #22
tst_csel_eq_adj_rn_zr_false_producer:
    tst     x0, x1
tst_csel_eq_adj_rn_zr_false_consumer:
    csel    x2, xzr, x4, eq
    cmp     x2, #22
    b.ne    fail
    ret

tst_csinc_adj_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
tst_csinc_adj_producer:
    tst     x0, x1
tst_csinc_adj_consumer:
    csinc   x2, x3, x4, ne
    cmp     x2, #23
    b.ne    fail
    ret

tst_csinc_adj_rd_rn_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
tst_csinc_adj_rd_rn_producer:
    tst     x0, x1
tst_csinc_adj_rd_rn_consumer:
    csinc   x3, x3, x4, eq
    cmp     x3, #11
    b.ne    fail
    ret

tst_csneg_adj_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #11
    mov     x4, #22
    movn    x5, #21
tst_csneg_adj_producer:
    tst     x0, x1
tst_csneg_adj_consumer:
    csneg   x2, x3, x4, ne
    cmp     x2, x5
    b.ne    fail
    ret
