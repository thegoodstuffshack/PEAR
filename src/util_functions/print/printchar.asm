; printchar.asm

[bits 64]
[default rel]

printchar_bitfont_width   equ 16 ; word
printchar_bitfont_height  equ 16
printchar_bytesperpixel   equ 4
printchar_printcolour_on  equ 0x00000000 ; black
printchar_printcolour_off equ 0x00FFFFFF ; white

; printchar
; copies a 16x16 bit character into VRAM
;
; IN rbx: ascii char
; IN rdi: dest (VRAM)
; IN r8d: screen width
printchars:
    sub rbx, ' '
    cmp rbx, '~' - ' '
    jna .printable
    xor rbx, rbx

.printable:
    shl rbx, 5 ; 32 bytes per character
    lea rsi, [printchar_bitfont]
    add rsi, rbx

    mov bx, printchar_bitfont_height
.line:
    mov cl, printchar_bitfont_width
.loop_bit:
    sub cl, 1
    mov dx, [rsi] ; printchar_bitfont_width bits read
    shr dx, cl
    and dx, 1
    jz .print_off

.print_on:
    mov dword [rdi], printchar_printcolour_on
    jmp .print_end
.print_off:
    mov dword [rdi], printchar_printcolour_off

.print_end:
    add rdi, printchar_bytesperpixel
    or cl, cl
    jnz .loop_bit

    add rsi, 2 ; printchar_bitfont_width / 8

.newline:
    mov eax, printchar_bytesperpixel
    mul r8d
    add rdi, rax
    sub rdi, printchar_bitfont_width * printchar_bytesperpixel

    sub bx, 1
    jnz .line

.end:
    ret

%strcat _printchar_bitfont FUNCTIONS "print/bitfont.bin"
printchar_bitfont: incbin _printchar_bitfont
