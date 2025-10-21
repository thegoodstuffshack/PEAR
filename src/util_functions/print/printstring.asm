; printstring.asm
;
; Requires: printchar.asm

[bits 64]
[default rel]

; printstring
; copies a null-terminated string of 16x16 bit characters into VRAM
; doesnt work well if string surpasses width of screen
;
; IN rbx: CHAR*
; IN rdi: dest (VRAM)
; IN r8d: screen width
printstring:
.loop:
    push rbx
    push rdi
    movzx rbx, byte [rbx]
    or rbx, rbx
    jz .end
    call printchars
    pop rdi
    pop rbx

    inc rbx
    add rdi, printchar_bitfont_width * printchar_bytesperpixel
    jmp .loop

.end:
    add rsp, 16
    ret
