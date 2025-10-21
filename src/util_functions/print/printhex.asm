; printhex.asm
;
; Requires: printchar.asm

[bits 64]
[default rel]

; printhex
; copies eight 16x16 bit hex characters into VRAM
;
; IN ebx: hex value
; IN rdi: dest (VRAM)
; IN r8d: screen width
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
    or cl, cl
    jz .end

    add rdi, printchar_bitfont_width * printchar_bytesperpixel
    jmp .loop

.end:
    ret
