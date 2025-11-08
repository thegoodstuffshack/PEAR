; printhex.asm
;
; Requires: printchar.asm

[bits 64]
[default rel]

; copies eight 16x16 bit hex characters into VRAM
;
; IN rdi: dest (VRAM)
; IN ebx: hex value
printhex:
    mov cl, 32
.loop:
    sub cl, 4
    push rdi
    push rbx
    push rcx

    shr ebx, cl
    and rbx, 0xF
    cmp ebx, 9
    ja .letters

.numbers:
    add ebx, '0'
    jmp .print
.letters:
    add ebx, 'A' - 0xA
.print:
    call printchar

    pop rcx
    pop rbx
    pop rdi
    add rdi, printchar_bitfont_width * printchar_bytesperpixel
    or cl, cl
    jnz .loop

.end:
    ret
