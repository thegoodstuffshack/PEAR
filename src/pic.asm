; pic.asm
;
; https://wiki.osdev.org/8259_PIC


PIC_MASTER_COMMAND equ 0x20
PIC_MASTER_DATA equ 0x21
PIC_SLAVE_COMMAND equ 0xA0
PIC_SLAVE_DATA equ 0xA1
PIC_EOI equ 0x20

PIC_MASTER_IRQ_VECTOR equ 0x30
PIC_SLACE_IRQ_VECTOR equ PIC_MASTER_IRQ_VECTOR + 0x8

PIC_CASCADE_IRQ equ 2

; https://wiki.osdev.org/Inline_Assembly/Examples#I/O_access
%macro PIC_IO_WAIT 0
    xor al, al
    out 0x80, al
%endmacro


; initialise PIC to 8086 mode, offset irq vectors, masks irqs
remap_pic:
    mov al, 0x11 ; initialisation required + ICW4
    out PIC_MASTER_COMMAND, al
    PIC_IO_WAIT
    mov al, 0x11 ; initialisation required + ICW4
    out PIC_SLAVE_COMMAND, al
    PIC_IO_WAIT

    mov al, PIC_MASTER_IRQ_VECTOR
    out PIC_MASTER_DATA, al
    PIC_IO_WAIT
    mov al, PIC_SLACE_IRQ_VECTOR
    out PIC_SLAVE_DATA, al
    PIC_IO_WAIT

    mov al, 1 << PIC_CASCADE_IRQ
    out PIC_MASTER_DATA, al
    PIC_IO_WAIT
    mov al, PIC_CASCADE_IRQ
    out PIC_SLAVE_DATA, al
    PIC_IO_WAIT

    mov al, 0x1 ; 8086 mode
    out PIC_MASTER_DATA, al
    PIC_IO_WAIT
    mov al, 0x1 ; 8086 mode
    out PIC_SLAVE_DATA, al
    PIC_IO_WAIT

    mov al, 0x00
    out PIC_MASTER_DATA, al
    mov al, 0x00
    out PIC_SLAVE_DATA, al

.end:
    ret


; IN al: irq number
acknowledge_irq:
    cmp al, 8
    mov al, PIC_EOI
    jb .master_pic
    out PIC_SLAVE_COMMAND, al
.master_pic:
    out PIC_MASTER_COMMAND, al
.end:
    ret
