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


; https://wiki.osdev.org/PCI
; https://uefi.org/specs/UEFI/2.10/14_Protocols_PCI_Bus_Support.html?highlight=pci%20bus%20support
; https://wiki.osdev.org/Intel_High_Definition_Audio#Identifying_HDA_on_a_machine
start:
    mov [SIS], rbx

    lea rbx, [helloworld]
    mov rdi, [SIS]
    mov r8d, [rdi + SIS_ScreenWidth]
    mov rdi, [rdi + SIS_VRAM]
    call printstring

    mov ebx, 0xF14B1337
    mov rdi, [SIS]
    mov r8d, [rdi + SIS_ScreenWidth]
    mov rdi, [rdi + SIS_VRAM]
    mov eax, r8d
    shl rax, 6
    add rdi, rax
    call printhex

    cli
    hlt


helloworld: db "Hello World!", 0

%strcat _include FUNCTIONS "include.asm"
%include _include
