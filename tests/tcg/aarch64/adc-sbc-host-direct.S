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

    mov     x0, #0
    mov     x8, #93
    svc     #0

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0
