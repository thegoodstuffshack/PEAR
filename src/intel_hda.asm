; intel_hda.asm

QEMU_HDA_VENDOR equ 0x8086
QEMU_HDA_DEVICE equ 0x2668

align 4
; PCI Header Type 0
INTEL_HDA_PCI_HEADER:
.vendor: dw 0
.device: dw 0
.command: dw 0
.status: dw 0
.revision: db 0
.progif: db 0
.subclass: db 0
.class: db 0
.cachelinesize: db 0
.latencytimer: db 0
.headertype: db 0
.bist: db 0
.bar0: dd 0
.bar1: dd 0
.bar2: dd 0
.bar3: dd 0
.bar4: dd 0
.bar5: dd 0
.cisptr: dd 0
.subsysvendor: dw 0
.subsysid: dw 0
.exprombar: dd 0
.capabilities_pointer: db 0
.reserved: times 7 db 0
.intline: db 0
.intpin: db 0
.mingrant: db 0
.maxlatency: db 0


; finds and populates the local hda header
find_intel_hda:
    mov ax, QEMU_HDA_DEVICE
    mov bx, QEMU_HDA_VENDOR
    call find_pci_device

    or eax, eax
    jnz .found

.not_found:
    lea rbx, [error_hda_not_found_str]
    jmp error_and_halt

.found:
    push ax

    ; read pci header
    xor rbx, rbx
.loop:
    xor eax, eax
    mov ax, [rsp]
    call read_pci_config
    lea rdi, [INTEL_HDA_PCI_HEADER]
    add rdi, rbx
    mov [rdi], eax
    add bl, 4
    cmp bl, 0x40
    jne .loop

    pop ax

    ; verify class, subclass, and header type
    mov rbx, [INTEL_HDA_PCI_HEADER.revision]
    mov rax, 0x007F0000FFFF0000 ; mask for check (also mask out multi function bit)
    and rbx, rax
    mov rax, 0x0000000004030000 ; header type 0, class 4, subclass 3
    cmp rbx, rax
    je .valid

.not_valid:
    lea rbx, [error_hda_not_hda_str]
    jmp error_and_halt

.valid:
    ; check BAR0
    mov al, [INTEL_HDA_PCI_HEADER.bar0]
    and al, 1
    jz .memory_space_bar

.io_space_bar:
    ; not handled - idek if hda has this
    lea rbx, [error_hda_io_space_bar_str]
    jmp error_and_halt

.memory_space_bar:
    mov al, [INTEL_HDA_PCI_HEADER.bar0]
    and al, 0x06
    jz .bar_32_bits

.bar_64_bits:
    ; not handled
    lea rbx, [error_hda_64_bit_bar_str]
    jmp error_and_halt

.bar_32_bits:
    and dword [INTEL_HDA_PCI_HEADER.bar0], 0xFFFFFFF0 ; do this now instead of everytime

.end:
    ret


error_hda_not_found_str: db "Error: intel HDA not found", 0
error_hda_not_hda_str: db "Error: intel HDA found but not actually", 0
error_hda_io_space_bar_str: db "Error: I/O space bar not supported", 0
error_hda_64_bit_bar_str: db "Error: 64 bit BAR not supported", 0
