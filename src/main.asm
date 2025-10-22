[bits 64]
[default rel]
    jmp start

_signature: db 'Proj EAR'

; SystemInfoStruct Pointer
SIS dq 0

; pointer to struct given in rbx
; SystemInfoStruct {
; UINT64    StructSize
; VOID*     SystemTable
; VOID*     VRAM
; UINT32    ScreenWidth
; UINT32    ScreenHeight
; ...
; }

SIS_Size            equ 0
SIS_SystemTable     equ 8
SIS_VRAM            equ 16
SIS_ScreenWidth     equ 24
SIS_ScreenHeight    equ 28


start:
    mov [SIS], rbx

    lea rbx, [helloworld]
    mov rdi, [SIS]
    mov r8d, [rdi + SIS_ScreenWidth]
    mov rdi, [rdi + SIS_VRAM]
    call printstring

    ; for now just configure for the qemu hda
    call find_intel_hda

    mov ebx, [INTEL_HDA_PCI_HEADER.bar0]
    mov rdi, [SIS]
    mov r8d, [rdi + SIS_ScreenWidth]
    mov rdi, [rdi + SIS_VRAM]
    xor rax, rax
    mov eax, r8d
    shl rax, 6 ; second line
    add rdi, rax
    call printhex

    cli
    hlt


; IN rbx: CHAR* error message
error_and_halt:
    mov rdi, [SIS]
    mov r8d, [rdi + SIS_ScreenWidth]
    mov rdi, [rdi + SIS_VRAM]
    call printstring
    cli
    hlt


helloworld: db "Hello World!", 0


%include "src/pci.asm"
%include "src/intel_hda.asm"

%strcat _include FUNCTIONS "include.asm"
%include _include
