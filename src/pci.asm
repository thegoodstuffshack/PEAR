; pci.asm

PCI_ADDRESS equ 0xCF8
PCI_DATA equ 0xCFC

; IN ah: Bus Number (8 bit)
; IN al: Device Number (5 bit)
; IN bh: Function Number (3 bit)
; IN bl: Register Offset (8 bit, lower 2 bits ignored)
; Returns eax: pci_config
read_pci_config:
    ; configures address
    mov dl, al
    shl dl, 3 ; device number

    shl eax, 8 ; bus number
    mov ah, dl
    and bh, 0b00000111
    or ah, bh
    and bl, 0b11111100
    mov al, bl
    ; 0000 0000 busn busn devi cfun rego fset
    or eax, 0x80000000	; set bit 31

    mov dx, PCI_ADDRESS
    out dx, eax
    mov dx, PCI_DATA
    in eax, dx
    ret


; IN ax: Device ID
; IN bx: Vendor ID
; Returns eax: (Bus Number << 8) | Device Number, sets high bit if found
find_pci_device:
    push ax
    push bx

    xor ah, ah
    xor bx, bx
.loop_bus:
    xor al, al
.loop_device:
    push ax
    call read_pci_config
    cmp eax, [rsp + 2]
    pop ax
    jz .found

    inc al
    cmp al, 0b00100000
    jnz .loop_device

    add ah, 1
    jnz .loop_bus

.not_found:
    xor eax, eax
    jmp .end

.found:
    and eax, 0x0000FFFF
    or eax, 0x80000000

.end:
    add rsp, 4
    ret
