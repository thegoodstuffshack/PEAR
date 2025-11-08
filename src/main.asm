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
    cli

    mov [SIS], rbx

    mov rbx, [SIS]
    mov r8d, [rbx + SIS_ScreenWidth]
    call init_printchar

    lea rbx, [helloworld]
    mov rdi, [SIS]
    mov rdi, [rdi + SIS_VRAM]
    call printstring

    call setup_gdt
    call remap_pic
    call setup_idt

    mov al, PIT_CHANNEL_0 | PIT_ACCESS_LOHI | PIT_OPMODE_2 | PIT_DIGIT_BIT
    mov bx, 0x001A ; 1193182 / 26 = 45891.62 Hz = 21.79 us
    call program_pit
    sti

    ; for now just configure for the qemu hda
    call find_intel_hda

    ; setup the intel hda
    ; ; call setup_intel_hda
    call map_intel_hda_interrupt
    call wake_hda_controller
    call setup_corb
    call setup_rirb
    call activate_dmas_and_interrupts
    call query_codec

    mov rcx, 1000
    call pit_sleep

    xor ebx, ebx
    mov bl, [INTEL_HDA_PCI_HEADER.intline]
    mov rdi, [SIS]
    xor r8, r8
    mov r8d, [rdi + SIS_ScreenWidth]
    mov rdi, [rdi + SIS_VRAM]
    shl r8, 6 ; second line
    add rdi, r8
    call printhex

    ; jmp $
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
%include "src/gdt.asm"
%include "src/pic.asm"
%include "src/idt.asm"
%include "src/pit.asm"

%strcat _include FUNCTIONS "include.asm"
%include _include
