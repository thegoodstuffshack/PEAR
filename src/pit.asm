; pit.asm

PIT_IO_CHANNEL_0 equ 0x40
PIT_IO_CONTROLLER equ 0x43
PIT_CHANNEL_0 equ 0b00_00_000_0
PIT_CHANNEL_1 equ 0b01_00_000_0
PIT_CHANNEL_2 equ 0b10_00_000_0
PIT_ACCESS_LO equ 0b00_01_000_0
PIT_ACCESS_HI equ 0b00_10_000_0
PIT_ACCESS_LOHI equ 0b00_11_000_0
PIT_OPMODE_0 equ 0b00_00_000_0
PIT_OPMODE_1 equ 0b00_00_001_0
PIT_OPMODE_2 equ 0b00_00_010_0
PIT_OPMODE_3 equ 0b00_00_011_0
PIT_OPMODE_4 equ 0b00_00_100_0
PIT_OPMODE_5 equ 0b00_00_101_0
PIT_DIGIT_BIT equ 0b00_00_000_0
PIT_DIGIT_BCD equ 0b00_00_000_1


; sets the PIT command byte and reload value
;
; IN al: Command Byte (7-6 channel, 5-4 access mode, 3-1 op mode, 0 digit mode)
; IN bx: reload value (bh hi, bl lo)
program_pit:
    xor dx, dx
    mov dl, al
    shr dl, 6
    add dl, PIT_IO_CHANNEL_0

    pushf
    cli
    out PIT_IO_CONTROLLER, al

    and al, PIT_ACCESS_LOHI
    cmp al, PIT_ACCESS_HI
    mov ax, bx
    jb .lo_only
    ja .lohi
    jmp .hi_only

.lohi:
    out dx, al
.hi_only:
    mov al, ah
.lo_only:
    out dx, al

.end:
    popf
    ret


;
pit_interrupt_handler:
    push rax
    mov rax, [.counter]
    cmp rax, byte 0
    jz .end ; no current pit_sleep active

    dec rax
    mov [.counter], rax

.end:
    mov al, 0 ; irq0
    call acknowledge_irq
    pop rax
    iretq

.counter: dq 0


; Waits at least (num - 1) * (reload_value / 1193182) seconds
; An input of 0 will be changed to 1 cycle
;
; IN rcx: num of pit cycles
pit_sleep:
    or rcx, rcx ; if input is 0, make it 1 (prevent softlock with current implementation)
    jnz .skip_add
    inc rcx
.skip_add:
    mov qword [pit_interrupt_handler.counter], rcx

    sti ; ensure interrupts are enabled before halting
.wait:
    hlt
    cmp qword [pit_interrupt_handler.counter], byte 0
    jnz .wait

.end:
    ret
