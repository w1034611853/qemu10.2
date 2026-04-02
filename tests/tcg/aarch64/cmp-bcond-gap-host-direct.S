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
    bl      cmp_gap1_case
    bl      subs_gap4_case
    bl      cmp_gap8_case
    bl      cmn_gap1_case
    bl      adds_gap4_case
    bl      cmn_gap8_case
    bl      cmn_vs_gap1_case
    bl      adds_vc_gap4_case
    bl      cmn_mi_gap4_case
    bl      adds_pl_gap1_case
    bl      adcs_eq_gap1_case
    bl      adcs_vs_gap4_case
    bl      adcs_rd_eq_gap1_case
    bl      adcs_rd_vs_gap4_case
    bl      sbcs_rd_cs_gap1_case
    bl      sbcs_rd_mi_gap4_case
    bl      adcs32_rd_eq_gap1_case
    bl      sbcs32_rd_mi_gap4_case
    bl      cmp_bad_gap_case
    bl      cmp_flags_writer_case
    bl      cmp_gap9_case
    bl      cmp_page_boundary_case
    bl      cmp_direct_cut_case
    bl      cmp_adjacent_precedence_case

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

cmp_gap1_case:
    mov     x0, #0x11
    mov     x1, #0x11
cmp_gap1_producer:
    cmp     x0, x1
    safe_gap_1
cmp_gap1_branch:
    b.eq    cmp_gap1_taken
    b       fail
cmp_gap1_taken:
    ret

subs_gap4_case:
    mov     x0, #0x22
    mov     x1, #0x22
subs_gap4_producer:
    subs    xzr, x0, x1
    safe_gap_4
subs_gap4_branch:
    b.eq    subs_gap4_taken
    b       fail
subs_gap4_taken:
    ret

cmp_gap8_case:
    mov     x0, #0x33
    mov     x1, #0x33
cmp_gap8_producer:
    cmp     x0, x1
    safe_gap_8
cmp_gap8_branch:
    b.eq    cmp_gap8_taken
    b       fail
cmp_gap8_taken:
    ret

cmn_gap1_case:
    mov     x0, #-1
    mov     x1, #1
cmn_gap1_producer:
    cmn     x0, x1
    safe_gap_1
cmn_gap1_branch:
    b.eq    cmn_gap1_taken
    b       fail
cmn_gap1_taken:
    ret

adds_gap4_case:
    mov     x0, #-1
    mov     x1, #1
adds_gap4_producer:
    adds    xzr, x0, x1
    safe_gap_4
adds_gap4_branch:
    b.eq    adds_gap4_taken
    b       fail
adds_gap4_taken:
    ret

cmn_gap8_case:
    mov     x0, #-1
    mov     x1, #1
cmn_gap8_producer:
    cmn     x0, x1
    safe_gap_8
cmn_gap8_branch:
    b.eq    cmn_gap8_taken
    b       fail
cmn_gap8_taken:
    ret

cmn_vs_gap1_case:
    mov     x0, #1
    lsl     x0, x0, #63
    sub     x0, x0, #1
    mov     x1, #1
cmn_vs_gap1_producer:
    cmn     x0, x1
    safe_gap_1
cmn_vs_gap1_branch:
    b.vs    cmn_vs_gap1_taken
    b       fail
cmn_vs_gap1_taken:
    ret

adds_vc_gap4_case:
    mov     x0, #-1
    mov     x1, #1
adds_vc_gap4_producer:
    adds    xzr, x0, x1
    safe_gap_4
adds_vc_gap4_branch:
    b.vc    adds_vc_gap4_taken
    b       fail
adds_vc_gap4_taken:
    ret

cmn_mi_gap4_case:
    mov     x0, #-2
    mov     x1, #1
cmn_mi_gap4_producer:
    cmn     x0, x1
    safe_gap_4
cmn_mi_gap4_branch:
    b.mi    cmn_mi_gap4_taken
    b       fail
cmn_mi_gap4_taken:
    ret

adds_pl_gap1_case:
    mov     x0, #-1
    mov     x1, #1
adds_pl_gap1_producer:
    adds    xzr, x0, x1
    safe_gap_1
adds_pl_gap1_branch:
    b.pl    adds_pl_gap1_taken
    b       fail
adds_pl_gap1_taken:
    ret

adcs_eq_gap1_case:
    mov     x15, #5
    cmp     x15, #3
    movn    x1, #0
    mov     x2, #0
adcs_eq_gap1_producer:
    adcs    xzr, x1, x2
    safe_gap_1
adcs_eq_gap1_branch:
    b.eq    adcs_eq_gap1_taken
    b       fail
adcs_eq_gap1_taken:
    ret

adcs_vs_gap4_case:
    mov     x15, #5
    cmp     x15, #3
    mov     x1, #1
    lsl     x1, x1, #63
    sub     x1, x1, #1
    mov     x2, #0
adcs_vs_gap4_producer:
    adcs    xzr, x1, x2
    safe_gap_4
adcs_vs_gap4_branch:
    b.vs    adcs_vs_gap4_taken
    b       fail
adcs_vs_gap4_taken:
    ret

adcs_rd_eq_gap1_case:
    mov     x15, #5
    cmp     x15, #3
    movn    x1, #0
    mov     x2, #0
adcs_rd_eq_gap1_producer:
    adcs    x3, x1, x2
    safe_gap_1
adcs_rd_eq_gap1_branch:
    b.eq    adcs_rd_eq_gap1_taken
    b       fail
adcs_rd_eq_gap1_taken:
    ret

adcs_rd_vs_gap4_case:
    mov     x15, #5
    cmp     x15, #3
    mov     x1, #1
    lsl     x1, x1, #63
    sub     x1, x1, #1
    mov     x2, #0
adcs_rd_vs_gap4_producer:
    adcs    x3, x1, x2
    safe_gap_4
adcs_rd_vs_gap4_branch:
    b.vs    adcs_rd_vs_gap4_taken
    b       fail
adcs_rd_vs_gap4_taken:
    ret

sbcs_rd_cs_gap1_case:
    mov     x15, #5
    cmp     x15, #3
    mov     x1, #5
    mov     x2, #3
sbcs_rd_cs_gap1_producer:
    sbcs    x3, x1, x2
    safe_gap_1
sbcs_rd_cs_gap1_branch:
    b.cs    sbcs_rd_cs_gap1_taken
    b       fail
sbcs_rd_cs_gap1_taken:
    ret

sbcs_rd_mi_gap4_case:
    mov     x15, #5
    cmp     x15, #3
    mov     x1, #1
    mov     x2, #3
sbcs_rd_mi_gap4_producer:
    sbcs    x3, x1, x2
    safe_gap_4
sbcs_rd_mi_gap4_branch:
    b.mi    sbcs_rd_mi_gap4_taken
    b       fail
sbcs_rd_mi_gap4_taken:
    ret

adcs32_rd_eq_gap1_case:
    mov     w15, #5
    cmp     w15, #3
    movn    w1, #0
    mov     w2, #0
adcs32_rd_eq_gap1_producer:
    adcs    w3, w1, w2
    safe_gap_1
adcs32_rd_eq_gap1_branch:
    b.eq    adcs32_rd_eq_gap1_taken
    b       fail
adcs32_rd_eq_gap1_taken:
    ret

sbcs32_rd_mi_gap4_case:
    mov     w15, #5
    cmp     w15, #3
    mov     w1, #1
    mov     w2, #3
sbcs32_rd_mi_gap4_producer:
    sbcs    w3, w1, w2
    safe_gap_4
sbcs32_rd_mi_gap4_branch:
    b.mi    sbcs32_rd_mi_gap4_taken
    b       fail
sbcs32_rd_mi_gap4_taken:
    ret

cmp_bad_gap_case:
    mov     x0, #0x44
    mov     x1, #0x44
cmp_bad_gap_producer:
    cmp     x0, x1
    adr     x9, cmp_bad_gap_case
cmp_bad_gap_branch:
    b.eq    cmp_bad_gap_taken
    b       fail
cmp_bad_gap_taken:
    ret

cmp_flags_writer_case:
    mov     x0, #0x55
    mov     x1, #0x55
    mov     x9, #-1
cmp_flags_writer_producer:
    cmp     x0, x1
    adds    x9, x9, #1
cmp_flags_writer_branch:
    b.eq    cmp_flags_writer_taken
    b       fail
cmp_flags_writer_taken:
    ret

cmp_gap9_case:
    mov     x0, #0x66
    mov     x1, #0x66
cmp_gap9_producer:
    cmp     x0, x1
    safe_gap_8
    nop
cmp_gap9_branch:
    b.eq    cmp_gap9_taken
    b       fail
cmp_gap9_taken:
    ret

    .balign 4096
    .space 4068
cmp_page_boundary_case:
    mov     x0, #0x77
    mov     x1, #0x77
cmp_page_boundary_producer:
    cmp     x0, x1
    nop
    nop
    nop
    nop
cmp_page_boundary_branch:
    b.eq    cmp_page_boundary_taken
    b       fail
cmp_page_boundary_taken:
    ret

cmp_direct_cut_case:
    mov     x0, #0x88
    mov     x1, #0x88
cmp_direct_cut_producer:
    cmp     x0, x1
    nop
    b       cmp_direct_cut_taken
cmp_direct_cut_branch:
    b.eq    cmp_direct_cut_dead
    b       fail
cmp_direct_cut_dead:
    b       fail
cmp_direct_cut_taken:
    ret

cmp_adjacent_precedence_case:
    mov     x0, #0x99
    mov     x1, #0x99
cmp_adjacent_precedence_producer:
    cmp     x0, x1
cmp_adjacent_precedence_branch:
    b.eq    cmp_adjacent_precedence_taken
    b       fail
cmp_adjacent_precedence_taken:
    ret
