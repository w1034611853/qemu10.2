    .text
    .global _start

_start:
    mov     x0, #1
    mov     w1, #1
    subs    xzr, x0, w1, uxtw
    b.eq    pass

fail:
    mov     x0, #1
    mov     x8, #93
    svc     #0

pass:
    mov     x0, #0
    mov     x8, #93
    svc     #0
