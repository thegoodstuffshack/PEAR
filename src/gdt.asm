; gdt.asm
;
; https://wiki.osdev.org/Global_Descriptor_Table


GDT_SIZE equ 7 * 64 ; 7 entries, tss is 2 entries
TSS_SIZE equ 0x68 ; TSS is zeroed for now


; initialises the new gdt and switches from the uefi gdt
; sets up the idt
setup_gdt:
    ; add entries
    xor rax, rax
    xor ebx, ebx
    xor cl, cl
    xor dl, dl
    xor r8, r8
    xor r12b, r12b
    call add_gdt_entry ; null descriptor

    xor rax, rax
    mov ebx, 0xFFFFF
    mov cl, 0x9A
    mov dl, 0xA
    mov r8, 0x8
    xor r12b, r12b
    call add_gdt_entry ; kernel mode cs

    xor rax, rax
    mov ebx, 0xFFFFF
    mov cl, 0x93
    mov dl, 0xC
    mov r8, 0x10
    xor r12b, r12b
    call add_gdt_entry ; kernel mode ds

    xor rax, rax
    mov ebx, 0xFFFFF
    mov cl, 0xF2
    mov dl, 0xC
    mov r8, 0x18
    xor r12b, r12b
    call add_gdt_entry ; user mode ds ; unused

    xor rax, rax
    mov ebx, 0xFFFFF
    mov cl, 0xFA
    mov dl, 0xA
    mov r8, 0x20
    xor r12b, r12b
    call add_gdt_entry ; user mode cs ; unused

    lea rax, [tss]
    mov ebx, TSS_SIZE - 1
    mov cl, 0x89
    xor dl, dl
    mov r8, 0x28
    mov r12b, 1
    call add_gdt_entry ; task state segment ; unused (for now)

    ; change to this gdt
    lea rbx, [gdt]
    push rbx
    push word GDT_SIZE - 1
    lgdt [rsp]
    add rsp, 10

    ; reload segment registers
    push qword 0x8 ; kernel mode cs offset
    lea rax, [.reload_cs_jump]
    push rax
    retfq

.reload_cs_jump:
    mov ax, 0x10 ; kernel mode ds offset
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

.end:
    ret


; IN rax: base
; IN ebx: limit
; IN cl: access byte
; IN dl: flags
; IN r8: gdt entry offset
; IN r12b: zero if 32-bit segment else 64-bit segment
add_gdt_entry:
    mov r9d, ebx ; limit bits 15:0
    and r9d, 0xFFFF

    mov r10, rax ; base bits 23:0
    and r10, 0xFFFFFF
    shl r10, 16
    or r9, r10

    and rcx, 0xFF
    shl rcx, 40 ; access byte
    or r9, rcx

    and rbx, 0xF0000
    shl rbx, 32 ; limit bits 19:16
    or r9, rbx

    and rdx, 0xF
    shl rdx, 52 ; flags
    or r9, rdx

    mov r10, rax ; base bits 31:24
    mov r11, 0xFF000000
    and r10, r11
    shl r10, 32
    or r9, r10

    lea rbx, [gdt] ; add entry
    mov [rbx + r8], r9

    or r12b, r12b
    jz .end

.bits_64_segment:
    shr rax, 32 ; base bits 63:32
    mov [rbx + r8 + 8], rax

.end:
    ret


    align 8
gdt: times GDT_SIZE db 0

    align 8
tss: times TSS_SIZE db 0
