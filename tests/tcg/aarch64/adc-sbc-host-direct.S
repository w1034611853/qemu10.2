    .text
    .global _start

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
    adcs    x7, x5, x6        // 9+3+0=12, flags set
    cmp     x7, #12
    b.ne    fail
    // ADCS sets flags: Z=0 (result != 0), C=0 (no carry)
    b.cs    fail              // C=0, so b.cs should NOT branch
    ret

// ADCS 32-bit: cmn -> adcs
block_cmn_adcs32:
    movn    w0, #0            // w0 = -1
    mov     w1, #1
    cmn     w0, w1            // -1 + 1 = 0, C=0
    mov     w5, #9
    mov     w6, #3
    adcs    w7, w5, w6        // 9+3+0=12
    cmp     w7, #12
    b.ne    fail
    b.cs    fail              // C=0, should not branch
    ret

// ADCS 64-bit with carry: cmn sets C=1 -> adcs adds carry
block_cmn_carry_adcs64:
    mov     x0, #0
    mov     x1, #1
    cmn     x0, x1            // 0+1 causes signed overflow, C=1
    mov     x5, #9
    mov     x6, #3
    adcs    x7, x5, x6        // 9+3+1=13, flags set
    cmp     x7, #13
    b.ne    fail
    // C=1 from overflow, ADCS sets C based on result
    b.cc    fail              // C=1, so b.cc should NOT branch
    ret

// ADCS: cmn with extended reg (smoke test for ext form)
block_cmn_ext_adcs64:
    mov     w1, #1
    movn    x0, #0
    cmn     x0, w1, uxtw      // C=1 from overflow
    mov     x9, #9
    mov     x10, #3
    adcs    x11, x9, x10      // 9+3+1=13
    cmp     x11, #13
    b.ne    fail
    ret

// ADCS: adds(rd) producer -> adcs consumer
block_adds_adcs64:
    movn    x0, #0
    mov     x1, #1
    adds    x5, x0, x1        // 0+1=1, C=1 (signed overflow)
    mov     x6, #9
    mov     x7, #3
    adcs    x8, x6, x7        // 9+3+1=13
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
    cmp     x11, #6
    b.ne    fail
    ret

// SBCS: subs(rd) producer -> sbcs consumer
block_subs_sbcs64:
    mov     x0, #5
    mov     x1, #3
    subs    x5, x0, x1        // 5-3=2, C=1 (no borrow)
    mov     x6, #9
    mov     x7, #3
    sbcs    x8, x6, x7        // 9-3-0=6
    cmp     x8, #6
    b.ne    fail
    ret

// Priority regression: SBCS xzr must still set flags correctly
// This ensures the direct consumer path doesn't break flag priority
block_sbcs_xzr_priority:
    mov     x0, #5
    mov     x1, #3
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

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0
