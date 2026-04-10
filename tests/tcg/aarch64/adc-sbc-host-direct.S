    .text
    .global _start

    .macro safe_gap_1
    nop
    .endm

_start:
    mov     x5, #9
    mov     x6, #3

    movn    x0, #0
    mov     x1, #1
    cmn     x0, x1

    adc     x7, x5, x6
    cmp     x7, #13
    b.ne    fail

    cmp     x5, x5
    sbc     x8, x5, x6
    cmp     x8, #6
    b.ne    fail

    mov     w5, #9
    mov     w6, #3

    movn    w0, #0
    mov     w1, #1
    cmn     w0, w1

    adc     w7, w5, w6
    cmp     w7, #13
    b.ne    fail

    movn    x0, #0
    mov     x1, #1
    mov     x6, #9
    mov     x7, #3
    adds    x5, x0, x1
    adc     x8, x6, x7
    cmp     x5, #0
    b.ne    fail
    cmp     x8, #13
    b.ne    fail

    movn    w0, #0
    mov     w1, #1
    mov     w6, #9
    mov     w7, #3
    adds    w5, w0, w1
    adc     w8, w6, w7
    cmp     w5, #0
    b.ne    fail
    cmp     w8, #13
    b.ne    fail

    mov     x0, #0
    mov     x1, #1
    mov     x6, #9
    mov     x7, #3
    subs    x5, x0, x1
    sbc     x8, x6, x7
    cmp     x5, #-1
    b.ne    fail
    cmp     x8, #5
    b.ne    fail

    mov     w0, #0
    mov     w1, #1
    mov     w6, #9
    mov     w7, #3
    subs    w5, w0, w1
    sbc     w8, w6, w7
    movn    w9, #0
    cmp     w5, w9
    b.ne    fail
    cmp     w8, #5
    b.ne    fail

    mov     x9, #9
    mov     x10, #3

    movn    x0, #0
    cmn     x0, #1
    adc     x11, x9, x10
    cmp     x11, #13
    b.ne    fail

    cmp     x9, #9
    sbc     x12, x9, x10
    cmp     x12, #6
    b.ne    fail

    movn    x0, #0
    adds    x13, x0, #1
    adc     x14, x9, x10
    cmp     x13, #0
    b.ne    fail
    cmp     x14, #13
    b.ne    fail

    mov     x0, #0
    subs    x15, x0, #1
    sbc     x16, x9, x10
    cmp     x15, #-1
    b.ne    fail
    cmp     x16, #5
    b.ne    fail

    mov     w9, #9
    mov     w10, #3

    movn    w0, #0
    cmn     w0, #1
    adc     w11, w9, w10
    cmp     w11, #13
    b.ne    fail

    cmp     w9, #9
    sbc     w12, w9, w10
    cmp     w12, #6
    b.ne    fail

    movn    w0, #0
    adds    w13, w0, #1
    adc     w14, w9, w10
    cmp     w13, #0
    b.ne    fail
    cmp     w14, #13
    b.ne    fail

    mov     w0, #0
    subs    w15, w0, #1
    sbc     w16, w9, w10
    movn    w17, #0
    cmp     w15, w17
    b.ne    fail
    cmp     w16, #5
    b.ne    fail

    mov     w1, #1
    mov     w2, #9

    movn    x0, #0
    cmn     x0, w1, uxtw
    adc     x11, x9, x10
    cmp     x11, #13
    b.ne    fail

    cmp     x9, w2, uxtw
    sbc     x12, x9, x10
    cmp     x12, #6
    b.ne    fail

    movn    x0, #0
    adds    x13, x0, w1, uxtw
    adc     x14, x9, x10
    cmp     x13, #0
    b.ne    fail
    cmp     x14, #13
    b.ne    fail

    mov     x0, #0
    subs    x15, x0, w1, uxtw
    sbc     x16, x9, x10
    cmp     x15, #-1
    b.ne    fail
    cmp     x16, #5
    b.ne    fail

    movn    w0, #0
    cmn     w0, w1, uxtw
    adc     w11, w9, w10
    cmp     w11, #13
    b.ne    fail

    cmp     w9, w2, uxtw
    sbc     w12, w9, w10
    cmp     w12, #6
    b.ne    fail

    movn    w0, #0
    adds    w13, w0, w1, uxtw
    adc     w14, w9, w10
    cmp     w13, #0
    b.ne    fail
    cmp     w14, #13
    b.ne    fail

    mov     w0, #0
    subs    w15, w0, w1, uxtw
    sbc     w16, w9, w10
    movn    w17, #0
    cmp     w15, w17
    b.ne    fail
    cmp     w16, #5
    b.ne    fail

    // Call ADCS/SBCS direct consumer tests
    bl      block_cmn_adcs64
    bl      block_cmn_adcs32
    bl      block_cmn_carry_adcs64
    bl      block_cmn_ext_adcs64
    bl      block_adds_adcs64
    bl      block_adds_adcs32
    bl      block_adds_imm_adcs64      // ADDS imm -> ADCS (adjacent)
    bl      block_adds_ext_adcs64      // ADDS ext -> ADCS (adjacent)
    bl      block_cmp_sbcs64
    bl      block_cmp_sbcs32
    bl      block_cmp_borrow_sbcs64
    bl      block_cmp_reg2_sbcs64
    bl      block_cmp_ext_sbcs64
    bl      block_subs_sbcs64
    bl      block_subs_sbcs32
    bl      block_subs_imm_sbcs64      // SUBS imm -> SBCS (adjacent)
    bl      block_subs_ext_sbcs64      // SUBS ext -> SBCS (adjacent)
    bl      block_adcs_adc64
    bl      block_adcs_adc32
    bl      block_adcs_adcs64
    bl      block_adcs_adcs32
    bl      block_sbcs_sbc64
    bl      block_sbcs_sbc32
    bl      block_sbcs_sbcs64
    bl      block_sbcs_sbcs32
    bl      block_adcs32_adc64
    bl      block_sbcs_xzr_priority
    bl      block_cmn_adc64_gap1
    bl      block_cmp_sbc64_gap1
    bl      block_cmn_adcs64_adjacent   // CMN->ADCS truly adjacent (narrowed)
    bl      block_cmp_sbcs64_adjacent   // CMP->SBCS truly adjacent (narrowed)

    mov     x0, #0
    mov     x8, #93
    svc     #0

// ------------------------------------------------------------
// ADCS/SBCS direct consumer tests
// These verify QEMU emits adc/sbb without extra carry-decode glue
// ------------------------------------------------------------

// ADCS 64-bit: cmn (compare-like) -> adcs
block_cmn_adcs64:
    movn    x0, #0            // x0 = -1
    mov     x1, #1
    cmn     x0, x1            // -1 + 1 = 0, no overflow, C=0
    mov     x5, #9
    mov     x6, #3
    adcs    x7, x5, x6        // 9+3+1=13, flags set (C from cmn=1)
    // ADCS result 13 has no unsigned overflow, so final C=0
    b.cs    fail              // C=0, so b.cs should NOT branch
    cmp     x7, #13
    b.ne    fail
    ret

// ADCS 32-bit: cmn -> adcs
block_cmn_adcs32:
    movn    w0, #0            // w0 = -1
    mov     w1, #1
    cmn     w0, w1            // -1 + 1 = 0, C=0
    mov     w5, #9
    mov     w6, #3
    adcs    w7, w5, w6        // 9+3+1=13 (C from cmn=1)
    b.cs    fail              // final C=0, should not branch
    cmp     w7, #13
    b.ne    fail
    ret

// ADCS 64-bit without carry: cmn sets C=0 -> adcs does not add carry
block_cmn_carry_adcs64:
    mov     x0, #0
    mov     x1, #1
    cmn     x0, x1            // 0+1=1, no overflow, C=0
    mov     x5, #9
    mov     x6, #3
    adcs    x7, x5, x6        // 9+3+0=12, flags set
    // ADCS result 12 has no unsigned overflow, so final C=0
    b.cs    fail              // C=0, so b.cs should NOT branch
    cmp     x7, #12
    b.ne    fail
    ret

// ADCS: cmn with extended reg (smoke test for ext form)
block_cmn_ext_adcs64:
    mov     w1, #1
    movn    x0, #0
    cmn     x0, w1, uxtw      // C=1 from overflow
    mov     x9, #9
    mov     x10, #3
    adcs    x11, x9, x10      // 9+3+1=13
    b.cs    fail              // final C=0
    cmp     x11, #13
    b.ne    fail
    ret

// ADCS: adds(rd) producer -> adcs consumer (reg form, truly adjacent)
block_adds_adcs64:
    mov     x6, #9
    mov     x7, #3
    movn    x0, #0
    mov     x1, #1
    adds    x5, x0, x1        // -1+1=0, C=1 (unsigned overflow)
    adcs    x8, x6, x7        // 9+3+1=13
    b.cs    fail              // final C=0
    cmp     x8, #13
    b.ne    fail
    ret

// ADCS: adds(rd) producer -> adcs consumer (32-bit reg form, truly adjacent)
block_adds_adcs32:
    mov     w6, #9
    mov     w7, #3
    movn    w0, #0
    mov     w1, #1
    adds    w5, w0, w1        // 0xffffffff+1=0, C=1 (unsigned overflow)
    adcs    w8, w6, w7        // 9+3+1=13
    b.cs    fail              // final C=0
    cmp     w8, #13
    b.ne    fail
    ret

// ADCS: adds imm producer -> adcs consumer (imm form, truly adjacent)
block_adds_imm_adcs64:
    mov     x6, #9
    mov     x7, #3
    movn    x0, #0
    adds    x5, x0, #1        // -1+1=0, C=1 (unsigned overflow)
    adcs    x8, x6, x7        // 9+3+1=13
    b.cs    fail              // final C=0
    cmp     x8, #13
    b.ne    fail
    ret

// ADCS: adds ext producer -> adcs consumer (ext form, truly adjacent)
block_adds_ext_adcs64:
    mov     x6, #9
    mov     x7, #3
    mov     w1, #1
    movn    x0, #0
    adds    x5, x0, w1, uxtw  // -1+1=0, C=1 (unsigned overflow)
    adcs    x8, x6, x7        // 9+3+1=13
    b.cs    fail              // final C=0
    cmp     x8, #13
    b.ne    fail
    ret

// SBCS 64-bit: cmp (compare-like) -> sbcs
block_cmp_sbcs64:
    mov     x0, #5
    mov     x1, #3
    cmp     x0, x1            // 5-3=2, C=1 (no borrow)
    mov     x5, #9
    mov     x6, #3
    sbcs    x7, x5, x6        // 9-3-!1 = 9-3-0 = 6
    b.cc    fail              // final C=1, so b.cc should NOT branch
    cmp     x7, #6
    b.ne    fail
    ret

// SBCS 32-bit: cmp -> sbcs
block_cmp_sbcs32:
    mov     w0, #5
    mov     w1, #3
    cmp     w0, w1            // C=1 (no borrow)
    mov     w5, #9
    mov     w6, #3
    sbcs    w7, w5, w6        // 9-3-0=6
    b.cc    fail              // final C=1, so b.cc should NOT branch
    cmp     w7, #6
    b.ne    fail
    ret

// SBCS with borrow (C=0 from cmp): 9-3-1=5
block_cmp_borrow_sbcs64:
    mov     x0, #3
    mov     x1, #5
    cmp     x0, x1            // 3-5: borrow, C=0
    mov     x5, #9
    mov     x6, #3
    sbcs    x7, x5, x6        // 9-3-!0 = 9-3-1 = 5
    b.cc    fail              // final C=1, so b.cc should NOT branch
    cmp     x7, #5
    b.ne    fail
    ret

// SBCS with register (smoke - ADCS/SBCS have no immediate form)
block_cmp_reg2_sbcs64:
    mov     x0, #5
    mov     x1, #1
    cmp     x0, x1            // C=1 (no borrow from 5-1)
    mov     x9, #9
    mov     x10, #1
    sbcs    x11, x9, x10      // 9-1-0=8
    cmp     x11, #8
    b.ne    fail
    ret

// SBCS extended (smoke test)
block_cmp_ext_sbcs64:
    mov     w2, #3
    mov     x0, #5
    cmp     x0, w2, uxtw      // C=1 (no borrow)
    mov     x9, #9
    mov     x10, #3
    sbcs    x11, x9, x10      // 9-3-0=6
    b.cc    fail              // final C=1
    cmp     x11, #6
    b.ne    fail
    ret

// SBCS: subs(rd) producer -> sbcs consumer (reg form, truly adjacent)
block_subs_sbcs64:
    mov     x6, #9
    mov     x7, #3
    mov     x0, #5
    mov     x1, #3
    subs    x5, x0, x1        // 5-3=2, C=1 (no borrow)
    sbcs    x8, x6, x7        // 9-3-0=6
    b.cc    fail              // final C=1, so b.cc should NOT branch
    cmp     x8, #6
    b.ne    fail
    ret

// SBCS: subs(rd) producer -> sbcs consumer (32-bit reg form, truly adjacent)
block_subs_sbcs32:
    mov     w6, #9
    mov     w7, #3
    mov     w0, #5
    mov     w1, #3
    subs    w5, w0, w1        // 5-3=2, C=1 (no borrow)
    sbcs    w8, w6, w7        // 9-3-0=6
    b.cc    fail              // final C=1, so b.cc should NOT branch
    cmp     w8, #6
    b.ne    fail
    ret

// SBCS: subs imm producer -> sbcs consumer (imm form, truly adjacent)
block_subs_imm_sbcs64:
    mov     x6, #9
    mov     x7, #3
    mov     x0, #5
    subs    x5, x0, #3        // 5-3=2, C=1 (no borrow)
    sbcs    x8, x6, x7        // 9-3-0=6
    b.cc    fail              // final C=1, so b.cc should NOT branch
    cmp     x8, #6
    b.ne    fail
    ret

// SBCS: subs ext producer -> sbcs consumer (ext form, truly adjacent)
block_subs_ext_sbcs64:
    mov     x6, #9
    mov     x7, #3
    mov     w1, #3
    mov     x0, #5
    subs    x5, x0, w1, uxtw  // 5-3=2, C=1 (no borrow)
    sbcs    x8, x6, x7        // 9-3-0=6
    b.cc    fail              // final C=1, so b.cc should NOT branch
    cmp     x8, #6
    b.ne    fail
    ret

// ADCS: adcs(rd) producer -> adc consumer (64-bit, truly adjacent)
block_adcs_adc64:
    mov     x0, #5
    mov     x6, #10
    mov     x7, #20
    cmp     x0, #3            // Seed C=1 for the producer
    movn    x1, #0            // x1 = -1
    mov     x2, #0
    adcs    x5, x1, x2        // -1+0+1=0, NZCV=0x6
    adc     x8, x6, x7        // 10+20+1=31, flags must stay from producer
    b.ne    fail              // Producer Z=1 must survive plain ADC
    b.cc    fail              // Producer C=1 must survive plain ADC
    cmp     x8, #31
    b.ne    fail
    ret

// ADCS: adcs(rd) producer -> adc consumer (32-bit, truly adjacent)
block_adcs_adc32:
    mov     x0, #5
    mov     w6, #10
    mov     w7, #20
    cmp     x0, #3            // Seed C=1 for the producer
    movn    w1, #0            // w1 = 0xffffffff
    mov     w2, #0
    adcs    w5, w1, w2        // 0xffffffff+0+1=0, NZCV=0x6
    adc     w8, w6, w7        // 10+20+1=31, flags must stay from producer
    b.ne    fail              // Producer Z=1 must survive plain ADC
    b.cc    fail              // Producer C=1 must survive plain ADC
    cmp     w8, #31
    b.ne    fail
    ret

// ADCS: adcs(rd) producer -> adcs consumer (64-bit, truly adjacent)
block_adcs_adcs64:
    mov     x0, #5
    mov     x6, #1
    lsl     x6, x6, #63       // INT64_MIN
    sub     x6, x6, #1        // INT64_MAX
    mov     x7, #0
    cmp     x0, #3            // Seed C=1 for the producer
    movn    x1, #0            // x1 = -1
    mov     x2, #0
    adcs    x5, x1, x2        // -1+0+1=0, NZCV=0x6
    adcs    x8, x6, x7        // INT64_MAX+0+1=INT64_MIN, NZCV=0x9
    b.pl    fail              // Final N=1 must come from the consumer
    b.cs    fail              // Final C=0 must come from the consumer
    b.vc    fail              // Final V=1 must come from the consumer
    mov     x9, #1
    lsl     x9, x9, #63
    cmp     x8, x9
    b.ne    fail
    ret

// ADCS: adcs(rd) producer -> adcs consumer (32-bit, truly adjacent)
block_adcs_adcs32:
    mov     x0, #5
    mov     w6, #1
    lsl     w6, w6, #31       // INT32_MIN
    sub     w6, w6, #1        // INT32_MAX
    mov     w7, #0
    cmp     x0, #3            // Seed C=1 for the producer
    movn    w1, #0            // w1 = 0xffffffff
    mov     w2, #0
    adcs    w5, w1, w2        // 0xffffffff+0+1=0, NZCV=0x6
    adcs    w8, w6, w7        // INT32_MAX+0+1=INT32_MIN, NZCV=0x9
    b.pl    fail              // Final N=1 must come from the consumer
    b.cs    fail              // Final C=0 must come from the consumer
    b.vc    fail              // Final V=1 must come from the consumer
    mov     w9, #1
    lsl     w9, w9, #31
    cmp     w8, w9
    b.ne    fail
    ret

// SBCS: sbcs(rd) producer -> sbc consumer (64-bit, truly adjacent)
block_sbcs_sbc64:
    mov     x0, #5
    mov     x6, #20
    mov     x7, #10
    cmp     x0, #3            // Seed C=1 for the producer
    mov     x1, #1
    mov     x2, #3
    sbcs    x5, x1, x2        // 1-3-0=-2, NZCV=0x8
    sbc     x8, x6, x7        // 20-10-1=9, flags must stay from producer
    b.pl    fail              // Producer N=1 must survive plain SBC
    b.cs    fail              // Producer C=0 must survive plain SBC
    cmp     x8, #9
    b.ne    fail
    ret

// SBCS: sbcs(rd) producer -> sbc consumer (32-bit, truly adjacent)
block_sbcs_sbc32:
    mov     x0, #5
    mov     w6, #20
    mov     w7, #10
    cmp     x0, #3            // Seed C=1 for the producer
    mov     w1, #1
    mov     w2, #3
    sbcs    w5, w1, w2        // 1-3-0=-2, NZCV=0x8
    sbc     w8, w6, w7        // 20-10-1=9, flags must stay from producer
    b.pl    fail              // Producer N=1 must survive plain SBC
    b.cs    fail              // Producer C=0 must survive plain SBC
    cmp     w8, #9
    b.ne    fail
    ret

// SBCS: sbcs(rd) producer -> sbcs consumer (64-bit, truly adjacent)
block_sbcs_sbcs64:
    mov     x0, #5
    mov     x6, #3
    mov     x7, #2
    cmp     x0, #3            // Seed C=1 for the producer
    mov     x1, #1
    mov     x2, #3
    sbcs    x5, x1, x2        // 1-3-0=-2, NZCV=0x8
    sbcs    x8, x6, x7        // 3-2-1=0, NZCV=0x6
    b.ne    fail              // Final Z=1 must come from the consumer
    b.cc    fail              // Final C=1 must come from the consumer
    b.mi    fail              // Final N=0 must come from the consumer
    cmp     x8, #0
    b.ne    fail
    ret

// SBCS: sbcs(rd) producer -> sbcs consumer (32-bit, truly adjacent)
block_sbcs_sbcs32:
    mov     x0, #5
    mov     w6, #3
    mov     w7, #2
    cmp     x0, #3            // Seed C=1 for the producer
    mov     w1, #1
    mov     w2, #3
    sbcs    w5, w1, w2        // 1-3-0=-2, NZCV=0x8
    sbcs    w8, w6, w7        // 3-2-1=0, NZCV=0x6
    b.ne    fail              // Final Z=1 must come from the consumer
    b.cc    fail              // Final C=1 must come from the consumer
    b.mi    fail              // Final N=0 must come from the consumer
    cmp     w8, #0
    b.ne    fail
    ret

// ADCS32 -> ADC64 mixed-width smoke test: must stay outside same-width direct support
block_adcs32_adc64:
    mov     x0, #5
    mov     x6, #10
    mov     x7, #20
    cmp     x0, #3            // Seed C=1 for the producer
    movn    w1, #0            // w1 = 0xffffffff
    mov     w2, #0
    adcs    w5, w1, w2        // 0xffffffff+0+1=0, NZCV=0x6
    adc     x8, x6, x7        // 10+20+1=31, mixed-width consumer
    b.ne    fail
    b.cc    fail
    cmp     x8, #31
    b.ne    fail
    ret

// Priority regression: SBCS xzr must still set flags correctly
// This ensures the direct consumer path doesn't break flag priority
block_sbcs_xzr_priority:
    mov     x0, #5
    mov     x1, #3
    mov     x2, #0
    cmp     x0, x1            // C=1 (no borrow from 5-3)
    sbcs    xzr, x1, x2       // xzr discards result, but flags are set
    // If flags corrupted by new path, b.cs might misbehave
    b.cc    fail               // C=1, so b.cc (C=0) should NOT branch
    // Verify flags by doing another op that depends on C
    mov     x5, #0
    adc     x6, x5, x5         // 0+0+C = C, should be 1
    cmp     x6, #1
    b.ne    fail
    ret

// Plain ADC gap case: carry should come from durable main flags, not pending consume
block_cmn_adc64_gap1:
    mov     x5, #9
    mov     x6, #3
    movn    x0, #0
    mov     x1, #1
block_cmn_adc64_gap1_producer:
    cmn     x0, x1
    safe_gap_1
block_cmn_adc64_gap1_consumer:
    adc     x7, x5, x6
    cmp     x7, #13
    b.ne    fail
    ret

// Plain SBC gap case: borrow should come from durable main flags, not pending consume
block_cmp_sbc64_gap1:
    mov     x5, #9
    mov     x6, #3
    mov     x0, #5
    mov     x1, #3
block_cmp_sbc64_gap1_producer:
    cmp     x0, x1
    safe_gap_1
block_cmp_sbc64_gap1_consumer:
    sbc     x8, x5, x6
    cmp     x8, #6
    b.ne    fail
    ret

// ------------------------------------------------------------
// Truly adjacent compare-like CMN/CMP -> ADCS/SBCS tests
// These verify the new adjacent lookahead is narrowed for compare-like
// ------------------------------------------------------------

// Truly adjacent CMN -> ADCS (64-bit): negative test for narrowing
// cmn and adcs are truly adjacent (no mov in between)
// This should NOT take the direct path (narrowed)
block_cmn_adcs64_adjacent:
    // Prepare registers for adcs BEFORE cmn
    mov     x5, #9
    mov     x6, #3
    // Load opaque inputs before the adjacent producer/consumer pair.
    adr     x12, block_cmn_adcs64_adjacent_inputs
    ldr     x0, [x12]
    ldr     x1, [x12, #8]
    // Producer and consumer are truly adjacent
    cmn     x0, x1            // producer: -1 + 1 = 0, C=1 (unsigned overflow)
    adcs    x7, x5, x6        // consumer: 9+3+1=13, truly adjacent to cmn
    b.cs    fail              // verify flags (final C=0)
    cmp     x7, #13
    b.ne    fail
    ret

// Truly adjacent CMP -> SBCS (64-bit): negative test for narrowing
// cmp and sbcs are truly adjacent (no mov in between)
// This should NOT take the direct path (narrowed)
block_cmp_sbcs64_adjacent:
    // Prepare registers for sbcs BEFORE cmp
    mov     x5, #9
    mov     x6, #3
    // Load opaque inputs before the adjacent producer/consumer pair.
    adr     x12, block_cmp_sbcs64_adjacent_inputs
    ldr     x0, [x12]
    ldr     x1, [x12, #8]
    // Producer and consumer are truly adjacent
    cmp     x0, x1            // producer: 5-3=2, C=1 (no borrow)
    sbcs    x7, x5, x6        // consumer: 9-3-0=6, truly adjacent to cmp
    b.cc    fail              // verify flags (final C=1)
    cmp     x7, #6
    b.ne    fail
    ret

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

    .balign 8
block_cmn_adcs64_adjacent_inputs:
    .xword 0xffffffffffffffff
    .xword 1

    .balign 8
block_cmp_sbcs64_adjacent_inputs:
    .xword 5
    .xword 3
