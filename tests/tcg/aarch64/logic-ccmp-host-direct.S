    .text
    .global _start

_start:
    bl      tst_ccmp_ne_adj_true_case
    bl      tst_ccmp_ne_adj_false_case
    bl      tst_ccmn_eq_adj_true_case
    bl      tst_ccmp_eq_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

tst_ccmp_ne_adj_true_case:
    mov     x0, #3
    mov     x1, #1
    mov     x3, #4
    mov     x4, #4
tst_ccmp_ne_adj_true_producer:
    tst     x0, x1
tst_ccmp_ne_adj_true_consumer:
    ccmp    x3, x4, #0xa, ne
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x5, #6
    b.ne    fail
    ret

tst_ccmp_ne_adj_false_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #4
    mov     x4, #4
tst_ccmp_ne_adj_false_producer:
    tst     x0, x1
tst_ccmp_ne_adj_false_consumer:
    ccmp    x3, x4, #0xa, ne
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x5, #0xa
    b.ne    fail
    ret

tst_ccmn_eq_adj_true_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #0
    mov     x4, #0
tst_ccmn_eq_adj_true_producer:
    tst     x0, x1
tst_ccmn_eq_adj_true_consumer:
    ccmn    x3, x4, #0x5, eq
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x5, #4
    b.ne    fail
    ret

tst_ccmp_eq_gap_case:
    mov     x0, #3
    mov     x1, #4
    mov     x3, #4
    mov     x4, #4
tst_ccmp_eq_gap_producer:
    tst     x0, x1
    nop
tst_ccmp_eq_gap_consumer:
    ccmp    x3, x4, #0xa, eq
    mrs     x5, nzcv
    lsr     x5, x5, #28
    cmp     x5, #6
    b.ne    fail
    ret
