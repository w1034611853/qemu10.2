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

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0
