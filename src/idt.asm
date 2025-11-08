; idt.asm
;
; https://wiki.osdev.org/Interrupt_Descriptor_Table


IDT_SIZE equ 256 * 16 ; 256 entries each 16 bytes long
DEFAULT_SEGMENT_SELECTOR equ 0x8 ; rpl 0, gdt, kernel mode cs (0x8)
IDT_GATETYPE_INTERRUPT equ 0xE
IDT_GATETYPE_TRAP equ 0xF


;
setup_idt:
    call add_idt_entries

    ; load new idt
    lea rax, [idt]
    push rax
    push word IDT_SIZE - 1
    lidt [rsp]
    add rsp, 10

.end:
    ret


add_idt_entries:
    ; add unhandled interrupts
    xor r8, r8
    lea rax, [general_protection_handler] ; general protection
    mov bx, DEFAULT_SEGMENT_SELECTOR
    mov cl, IDT_GATETYPE_INTERRUPT
    xor dl, dl
.loop:
    call add_idt_entry
    add r8, 0x10
    cmp r8, 31 * 16 + 0x10
    jne .loop

    mov bx, DEFAULT_SEGMENT_SELECTOR
    mov cl, IDT_GATETYPE_INTERRUPT
    xor dl, dl
    lea rax, [pit_interrupt_handler]
    mov r8, (PIC_MASTER_IRQ_VECTOR + 0) * 16 ; irq0
    call add_idt_entry ; IRQ0 pit_interrupt_handler

    ; lea rax, [irq1_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq2_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq3_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq4_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq5_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq6_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq7_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq8_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq9_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq10_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq11_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq12_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq13_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq14_handler]
    ; add r8, byte 16
    ; call add_idt_entry
    ; lea rax, [irq15_handler]
    ; add r8, byte 16
    ; call add_idt_entry

.end:
    ret

; all ISTs zero for now
; IN rax: offset
; IN bx: segment selector
; IN cl: gate type
; IN dl: DPL
; IN r8: idt entry offset
add_idt_entry:
    push rax
    push bx
    push cx
    push dx

    mov r9d, eax ; offset bits 15:0
    and r9d, 0x0000FFFF

    shl ebx, 16 ; segment selector
    or r9d, ebx

    and rcx, 0xF ; gate type
    shl rcx, 40
    or r9, rcx

    and rdx, 0x3 ; DPL
    or rdx, 0x4 ; present bit
    shl rdx, 45
    or r9, rdx

    mov r10, rax
    shr r10, 16 ; offset bits 16:31
    shl r10, 48
    or r9, r10

    lea rbx, [idt] ; add entry
    mov [rbx + r8], r9
    shr rax, 32 ; offset bits 32:63
    mov [rbx + r8 + 8], rax

.end:
    pop dx
    pop cx
    pop bx
    pop rax
    ret


;
general_protection_handler:
    mov rdi, [SIS]
    mov rdi, [rdi + SIS_VRAM]
    lea rbx, [gp_interrupt_string]
    call printstring
    hlt
    ; iretq

;
; unhandled_interrupt_w_number:
;     push rbx
;     mov rdi, [SIS]
;     mov rdi, [rdi + SIS_VRAM]
;     lea rbx, [gp_interrupt_string]
;     call printstring

;     pop rbx
;     mov rdi, [SIS]
;     mov r8d, [rdi + SIS_ScreenWidth]
;     shl r8, 6
;     mov rdi, [rdi + SIS_VRAM]
;     add rdi, r8 ; next line
;     add rdi, r8 ; next line
;     add rdi, r8 ; next line
;     add rdi, r8 ; next line
;     call printhex
;     hlt


; only PIT uses irq0
irq0_handler:
    jmp pit_interrupt_handler

;
; irq1_handler:
;     mov ebx, 0x1001
;     jmp unhandled_interrupt_w_number
; ;
; irq2_handler:
;     mov ebx, 0x2002
;     jmp unhandled_interrupt_w_number
; ;
; irq3_handler:
;     mov ebx, 0x3003
;     jmp unhandled_interrupt_w_number
; ;
; irq4_handler:
;     mov ebx, 0x4004
;     jmp unhandled_interrupt_w_number
; ;
; irq5_handler:
;     mov ebx, 0x5005
;     jmp unhandled_interrupt_w_number
; ;
; irq6_handler:
;     mov ebx, 0x6006
;     jmp unhandled_interrupt_w_number
; ;
; irq7_handler:
;     mov ebx, 0x7007
;     jmp unhandled_interrupt_w_number
; ;
; irq8_handler:
;     mov ebx, 0x8008
;     jmp unhandled_interrupt_w_number
; ;
; irq9_handler:
;     mov ebx, 0x9009
;     jmp unhandled_interrupt_w_number
; ;
; irq10_handler:
;     mov ebx, 0x1010
;     jmp unhandled_interrupt_w_number
; ;
; irq11_handler:
;     mov ebx, 0x1111
;     jmp unhandled_interrupt_w_number
; ;
; irq12_handler:
;     mov ebx, 0x1212
;     jmp unhandled_interrupt_w_number
; ;
; irq13_handler:
;     mov ebx, 0x1313
;     jmp unhandled_interrupt_w_number
; ;
; irq14_handler:
;     mov ebx, 0x1414
;     jmp unhandled_interrupt_w_number
; ;
; irq15_handler:
;     mov ebx, 0x1515
;     jmp unhandled_interrupt_w_number





gp_counter: dw 0
gp_interrupt_string: db "this interrupt was eaten", 0

    align 16
idt: times IDT_SIZE db 0
