[bits 64]
[default rel]
    jmp start

_signature: db 'SIGNATUR'

; SystemInfoStruct Pointer
SIS dq 0

; pointer to struct given in rbx
; SystemInfoStruct {
; UINT64    StructSize
; VOID*     SystemTable
; VOID*     VRAM
; UINT32    ScreenWidth
; UINT32    ScreenHeight
; VOID*     Data
; UINT64    DataSize
; ...
; }

SIS_Size            equ 0
SIS_SystemTable     equ 8
SIS_VRAM            equ 16
SIS_ScreenWidth     equ 24
SIS_ScreenHeight    equ 28
SIS_Data            equ 32
SIS_DataSize        equ 40


start:
    mov [SIS], rbx

    mov rdi, [rbx + SIS_VRAM]
    mov rsi, [rbx + SIS_Data]
    push word 3 ; width
    push word 17 ; height
    call print_bit_art

    cli
    hlt

PRINT_COLOUR_ON equ 0x00FFFFFF
PRINT_COLOUR_OFF equ 0x00000000

; IN rdi: VRAM_addr
; IN rsi: bit_art_addr
; PUSH word: height
; PUSH word: width (bytes)
; assumes width and height >= 1
print_bit_art:
    push rbp
    mov rbp, rsp

.line:
    mov dx, [rbp + 18]
.loop_byte:
    mov cl, 8
.loop_bit:
    sub cl, 1
    mov bl, [rsi]
    shr bl, cl
    and bl, 1
    jz .print_off

.print_on:
    mov dword [rdi], PRINT_COLOUR_ON
    jmp .print_end

.print_off:
    mov dword [rdi], PRINT_COLOUR_OFF

.print_end:
    add rdi, 4
    or cl, cl
    jnz .loop_bit

    add rsi, 1
    sub dx, 1
    jnz .loop_byte

.newline:
    mov rbx, [SIS]
    xor rax, rax
    mov eax, dword [rbx + SIS_ScreenWidth]
    shl rax, 2
    add rdi, rax
    movzx rax, word [rbp + 18]
    shl rax, 5
    sub rdi, rax

    sub word [rbp + 16], 1
    jnz .line

.end:
    pop rbp
    ret 4
