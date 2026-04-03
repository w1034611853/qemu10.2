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
    bl      cmp_csel_eq_gap1_case
    bl      cmp_csel_lt_gap4_case
    bl      cmp_csel_hi_gap8_case
    bl      cmp_csel_dst_is_cmp_ne_gap1_case
    bl      cmp64_csel_dst_is_lhs_ls_gap1_case
    bl      cmp64_cset_orr_shift_ne_gap1_case
    bl      cmp64_csel_hs_chain_gap1_case
    bl      cmp64_cset_orr_shift_eq_gap1_case
    bl      cmp32_csel_eq_gap1_case
    bl      cmp32_csel_hi_gap4_case
    bl      cmp32_cset_eq_gap1_case
    bl      cmp32_csel_dst_is_false_gap1_case
    bl      cmp32_csel_dst_is_true_gap4_case
    bl      cmp32_cset_gt_gap1_case
    bl      cmp32_cset_dst_is_cmp_eq_gap1_case
    bl      cmp32_cset_logic_merge_gap1_case
    bl      cmp32_cset_then_ccmp_gap1_case
    bl      cmp32_cset_call_eq_gap1_case
    bl      cmp32_cset_call_reads_flags_eq_gap1_case
    bl      cmp32_csel64_dst_is_false_ne_gap1_case
    bl      cmp64_csel_xzr_eq_gap1_case
    bl      cmp64_csel_pl_gap1_case
    bl      cmp64_csel_mi_gap1_case
    bl      cmp32_cset_ne_gap1_case
    bl      cmp32_cset_ls_gap1_case
    bl      cmp64_cset_pl_gap1_case
    bl      cmp64_cset_mi_gap1_case
    bl      cmp_csinc_eq_gap1_case
    bl      cmp_csinv_eq_gap4_case
    bl      cmp_csneg_eq_gap8_case
    bl      cmp_cset_eq_gap1_case
    bl      cmp_csetm_hi_gap4_case
    bl      cmp_csel_bad_gap_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_csel_eq_gap1_case:
    mov     x0, #0x11
    mov     x1, #0x11
    mov     x3, #11
    mov     x4, #22
cmp_csel_eq_gap1_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csel_eq_gap1_consumer:
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret

cmp_csel_lt_gap4_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csel_lt_gap4_producer:
    cmp     x0, x1
    safe_gap_4
cmp_csel_lt_gap4_consumer:
    csel    x2, x3, x4, lt
    cmp     x2, #11
    b.ne    fail
    ret

cmp_csel_hi_gap8_case:
    mov     x0, #9
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csel_hi_gap8_producer:
    cmp     x0, x1
    safe_gap_8
cmp_csel_hi_gap8_consumer:
    csel    x2, x3, x4, hi
    cmp     x2, #11
    b.ne    fail
    ret

cmp_csel_dst_is_cmp_ne_gap1_case:
    mov     x0, #5
    mov     x4, #3
cmp_csel_dst_is_cmp_ne_gap1_producer:
    cmp     x0, #0
    sub     x2, x0, #1
    and     x2, x2, x4
    safe_gap_1
cmp_csel_dst_is_cmp_ne_gap1_consumer:
    csel    x0, x2, x0, ne
    cmp     x0, #0
    b.ne    fail
    ret

cmp64_csel_dst_is_lhs_ls_gap1_case:
    mov     x19, #3
    mov     x27, #9
    mov     x3, #22
cmp64_csel_dst_is_lhs_ls_gap1_producer:
    cmp     x19, x27
    safe_gap_1
cmp64_csel_dst_is_lhs_ls_gap1_consumer:
    csel    x19, x19, x3, ls
    cmp     x19, #3
    b.ne    fail
    ret

cmp64_cset_orr_shift_ne_gap1_case:
    mov     x19, #3
    mov     x27, #9
    mov     x20, #5
cmp64_cset_orr_shift_ne_gap1_producer:
    cmp     x19, x27
    safe_gap_1
cmp64_cset_orr_shift_ne_gap1_consumer:
    cset    x2, ne
    orr     x2, x20, x2, lsl #2
    cmp     x2, #5
    b.ne    fail
    ret

cmp64_csel_hs_chain_gap1_case:
    mov     x0, #1
    lsl     x0, x0, #17       /* 0x20000 */
    mov     x19, x0
cmp64_csel_hs_chain_gap1_producer:
    cmp     x19, #0x20, lsl #12
    movz    x4, #2, lsl #16   /* 0x20000 */
cmp64_csel_hs_chain_gap1_consumer:
    csel    x4, x19, x4, hs
    cmp     x19, x4
    csel    x0, x19, x4, hs
    mov     x5, #1
    lsl     x5, x5, #17
    cmp     x0, x5
    b.ne    fail
    ret

cmp64_cset_orr_shift_eq_gap1_case:
    mov     x19, #7
    mov     x27, #7
    mov     x20, #1
cmp64_cset_orr_shift_eq_gap1_producer:
    cmp     x19, x27
    safe_gap_1
cmp64_cset_orr_shift_eq_gap1_consumer:
    cset    x2, eq
    orr     x2, x20, x2, lsl #2
    cmp     x2, #5
    b.ne    fail
    ret

cmp32_csel_eq_gap1_case:
    mov     w0, #0x11
    mov     w1, #0x11
    mov     w3, #11
    mov     w4, #22
cmp32_csel_eq_gap1_producer:
    cmp     w0, w1
    safe_gap_1
cmp32_csel_eq_gap1_consumer:
    csel    w2, w3, w4, eq
    cmp     w2, #11
    b.ne    fail
    ret

cmp32_csel_hi_gap4_case:
    mov     w0, #9
    mov     w1, #3
    mov     w3, #11
    mov     w4, #22
cmp32_csel_hi_gap4_producer:
    cmp     w0, w1
    safe_gap_4
cmp32_csel_hi_gap4_consumer:
    csel    w2, w3, w4, hi
    cmp     w2, #11
    b.ne    fail
    ret

cmp32_cset_eq_gap1_case:
    mov     w0, #0x11
    mov     w1, #0x11
cmp32_cset_eq_gap1_producer:
    cmp     w0, w1
    safe_gap_1
cmp32_cset_eq_gap1_consumer:
    cset    w2, eq
    cmp     w2, #1
    b.ne    fail
    ret

cmp32_csel_dst_is_false_gap1_case:
    mov     w0, #7
    mov     w1, #7
    mov     w2, #11
    mov     w21, #22
cmp32_csel_dst_is_false_gap1_producer:
    cmp     w0, w1
    safe_gap_1
cmp32_csel_dst_is_false_gap1_consumer:
    csel    w21, w2, w21, eq
    cmp     w21, #11
    b.ne    fail
    ret

cmp32_csel_dst_is_true_gap4_case:
    mov     w0, #1
    mov     w1, #3
    mov     w21, #11
    mov     w23, #22
cmp32_csel_dst_is_true_gap4_producer:
    cmp     w0, w1
    safe_gap_4
cmp32_csel_dst_is_true_gap4_consumer:
    csel    w21, w21, w23, lt
    cmp     w21, #11
    b.ne    fail
    ret

cmp32_cset_gt_gap1_case:
    mov     w0, #9
    mov     w1, #3
cmp32_cset_gt_gap1_producer:
    cmp     w0, w1
    safe_gap_1
cmp32_cset_gt_gap1_consumer:
    cset    w2, gt
    cmp     w2, #1
    b.ne    fail
    ret

cmp32_cset_dst_is_cmp_eq_gap1_case:
    mov     w5, #0
cmp32_cset_dst_is_cmp_eq_gap1_producer:
    cmp     w5, #0
    safe_gap_1
cmp32_cset_dst_is_cmp_eq_gap1_consumer:
    cset    w5, eq
    cmp     w5, #1
    b.ne    fail
    ret

cmp32_cset_logic_merge_gap1_case:
    mov     w5, #0
    mov     w4, #1
    mov     w2, #0
cmp32_cset_logic_merge_gap1_producer:
    cmp     w5, #0
    movn    w8, #0x467
cmp32_cset_logic_merge_gap1_consumer:
    cset    w5, eq
    asr     w8, w8, w2
    and     w4, w5, w4
    and     w5, w8, #1
    orr     w4, w4, w5
    cmp     w4, #1
    b.ne    fail
    ret

cmp32_cset_then_ccmp_gap1_case:
    mov     w20, #6
    mov     w22, #9
cmp32_cset_then_ccmp_gap1_producer:
    cmp     w20, #6
    safe_gap_1
cmp32_cset_then_ccmp_gap1_consumer:
    cset    w1, eq
    cmp     w1, #0
    ccmp    w22, #10, #0, ne
    b.ne    cmp32_cset_then_ccmp_gap1_ok
    b       fail
cmp32_cset_then_ccmp_gap1_ok:
    ret

cmp32_cset_call_eq_gap1_case:
    mov     w0, #0
    mov     w1, #7
    mov     w2, #8
    mov     w3, #9
    mov     w4, #10
cmp32_cset_call_eq_gap1_producer:
    cmp     w0, #0
    mov     x0, #123
cmp32_cset_call_eq_gap1_consumer:
    cset    w5, eq
    cmp     w5, #1
    b.ne    fail
    mov     x17, lr
    bl      return_w5_u32
    mov     lr, x17
    cmp     w0, #1
    b.ne    fail
    ret

cmp32_cset_call_reads_flags_eq_gap1_case:
    mov     w0, #0
cmp32_cset_call_reads_flags_eq_gap1_producer:
    cmp     w0, #0
    mov     x0, #123
cmp32_cset_call_reads_flags_eq_gap1_consumer:
    cset    w5, eq
    mov     x17, lr
    bl      return_eq_flag_u32
    mov     lr, x17
    cmp     w0, #1
    b.ne    fail
    ret

cmp32_csel64_dst_is_false_ne_gap1_case:
    mov     w2, #1
    mov     x1, #5
    mov     x22, #9
cmp32_csel64_dst_is_false_ne_gap1_producer:
    cmp     w2, #0
    add     x6, x1, x22
cmp32_csel64_dst_is_false_ne_gap1_consumer:
    csel    x1, x6, x1, ne
    cmp     x1, #14
    b.ne    fail
    ret

cmp64_csel_xzr_eq_gap1_case:
    mov     x0, #0
cmp64_csel_xzr_eq_gap1_producer:
    cmp     x0, #0
    mov     x2, #99
cmp64_csel_xzr_eq_gap1_consumer:
    csel    x0, x2, xzr, eq
    cmp     x0, #99
    b.ne    fail
    ret

cmp64_csel_pl_gap1_case:
    mov     x0, #5
    mov     x3, #11
    mov     x4, #22
cmp64_csel_pl_gap1_producer:
    cmp     x0, #0
    safe_gap_1
cmp64_csel_pl_gap1_consumer:
    csel    x2, x3, x4, pl
    cmp     x2, #11
    b.ne    fail
    ret

cmp64_csel_mi_gap1_case:
    mov     x0, #0
    mov     x3, #11
    mov     x4, #22
cmp64_csel_mi_gap1_producer:
    cmp     x0, #1
    safe_gap_1
cmp64_csel_mi_gap1_consumer:
    csel    x2, x3, x4, mi
    cmp     x2, #11
    b.ne    fail
    ret

cmp32_cset_ne_gap1_case:
    mov     w4, #7
cmp32_cset_ne_gap1_producer:
    cmp     w4, #0
    safe_gap_1
cmp32_cset_ne_gap1_consumer:
    cset    w4, ne
    cmp     w4, #1
    b.ne    fail
    ret

cmp32_cset_ls_gap1_case:
    mov     w5, #3
    mov     w6, #9
cmp32_cset_ls_gap1_producer:
    cmp     w5, w6
    safe_gap_1
cmp32_cset_ls_gap1_consumer:
    cset    w2, ls
    cmp     w2, #1
    b.ne    fail
    ret

cmp64_cset_pl_gap1_case:
    mov     x0, #5
cmp64_cset_pl_gap1_producer:
    cmp     x0, #0
    safe_gap_1
cmp64_cset_pl_gap1_consumer:
    cset    x2, pl
    cmp     x2, #1
    b.ne    fail
    ret

cmp64_cset_mi_gap1_case:
    mov     x0, #0
cmp64_cset_mi_gap1_producer:
    cmp     x0, #1
    safe_gap_1
cmp64_cset_mi_gap1_consumer:
    cset    x2, mi
    cmp     x2, #1
    b.ne    fail
    ret

cmp_csinc_eq_gap1_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csinc_eq_gap1_producer:
    cmp     x0, x1
    safe_gap_1
cmp_csinc_eq_gap1_consumer:
    csinc   x2, x3, x4, eq
    cmp     x2, #23
    b.ne    fail
    ret

cmp_csinv_eq_gap4_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csinv_eq_gap4_producer:
    cmp     x0, x1
    safe_gap_4
cmp_csinv_eq_gap4_consumer:
    csinv   x2, x3, x4, eq
    mov     x5, #-23
    cmp     x2, x5
    b.ne    fail
    ret

cmp_csneg_eq_gap8_case:
    mov     x0, #1
    mov     x1, #3
    mov     x3, #11
    mov     x4, #22
cmp_csneg_eq_gap8_producer:
    cmp     x0, x1
    safe_gap_8
cmp_csneg_eq_gap8_consumer:
    csneg   x2, x3, x4, eq
    mov     x5, #-22
    cmp     x2, x5
    b.ne    fail
    ret

cmp_cset_eq_gap1_case:
    mov     x0, #0x11
    mov     x1, #0x11
cmp_cset_eq_gap1_producer:
    cmp     x0, x1
    safe_gap_1
cmp_cset_eq_gap1_consumer:
    cset    x2, eq
    cmp     x2, #1
    b.ne    fail
    ret

cmp_csetm_hi_gap4_case:
    mov     x0, #9
    mov     x1, #3
cmp_csetm_hi_gap4_producer:
    cmp     x0, x1
    safe_gap_4
cmp_csetm_hi_gap4_consumer:
    csetm   x2, hi
    mov     x5, #-1
    cmp     x2, x5
    b.ne    fail
    ret

cmp_csel_bad_gap_case:
    mov     x0, #0x44
    mov     x1, #0x44
    mov     x3, #11
    mov     x4, #22
cmp_csel_bad_gap_producer:
    cmp     x0, x1
    adr     x9, cmp_csel_bad_gap_case
cmp_csel_bad_gap_consumer:
    csel    x2, x3, x4, eq
    cmp     x2, #11
    b.ne    fail
    ret

return_w5_u32:
    mov     w0, w5
    ret

return_eq_flag_u32:
    cset    w0, eq
    ret
