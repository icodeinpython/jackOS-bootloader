[section .init]
[BITS 64]
[EXTERN kmain]
start:
    call kmain
.halt:
    hlt
    jmp .halt