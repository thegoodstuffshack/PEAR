; intel_hda.asm
;
; https://www.intel.com/content/dam/www/public/us/en/documents/product-specifications/high-definition-audio-specification.pdf


QEMU_HDA_ICH6_VENDOR equ 0x8086
QEMU_HDA_ICH6_DEVICE equ 0x2668
QEMU_HDA_ICH9_VENDOR equ 0x8086
QEMU_HDA_ICH9_DEVICE equ 0x293e

ACTIVE_HDA_VENDOR equ QEMU_HDA_ICH9_VENDOR
ACTIVE_HDA_DEVICE equ QEMU_HDA_ICH9_DEVICE


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

ihda_reg_bar dq 0

; Intel HDA Device Register Offsets
IHDA_REG_GLOBALCAPABILITIES equ 0x00
IHDA_REG_GLOBALCONTROL equ 0x08
IHDA_REG_STATESTS equ 0x0E
IHDA_REG_INTERRUPTCONTROL equ 0x20
IHDA_REG_INTERRUPTSTATUS equ 0x24
IHDA_REG_CORB_LBA equ 0x40
IHDA_REG_CORBWP equ 0x48
IHDA_REG_CORBRP equ 0x4A
IHDA_REG_CORBCTL equ 0x4C
IHDA_REG_CORBSIZE equ 0x4E
IHDA_REG_RIRB_LBA equ 0x50
IHDA_REG_RIRBWP equ 0x58
IHDA_REG_RIRBINTCNT equ 0x5A
IHDA_REG_RIRBCTL equ 0x5C
IHDA_REG_RIRBSTS equ 0x5D
IHDA_REG_RIRBSIZE equ 0x5E
IHDA_REG_STREAMDESC equ 0x80
IHDA_REG_STREAMCBL equ 0x88
IHDA_REG_STREAMLVI equ 0x8C
IHDA_REG_STREAMFMT equ 0x92
IHDA_REG_STREAMBDL_LBA equ 0x98
IHDA_REG_STREAMBDL_UBA equ 0x9C

; Intel HDA CODEC Node Commands
IHDA_NODECMD_GETPARAM equ 0xF0000
IHDA_NODECMD_SETSTREAMCHAN equ 0x70600
IHDA_NODECMD_PINCONTROL equ 0x70700
IHDA_NODECMD_EAPDBTLENABLE equ 0x70C00
IHDA_NODECMD_SETFORMAT equ 0x20000
IHDA_NODECMD_AMPSETGAIN equ 0x30000
IHDA_NODEDAT_NODECOUNT equ 0x04
IHDA_NODEDAT_FNGROUPTYPE equ 0x05
IHDA_NODEDAT_WIDGETCAP equ 0x09
IHDA_NODEDAT_PINCAP equ 0x0C
IHDA_NODEDAT_SUPPCMRATES equ 0x0A
IHDA_NODEDAT_SUPFORMATS equ 0x0B
IHDA_NODEDAT_OUTAMPCAP equ 0x12
IHDA_CONVFORMAT_16 equ 0x0010 ; 16 bit 48kHz PCM audio

; finds and populates the local hda header
find_intel_hda:
    mov ax, ACTIVE_HDA_DEVICE
    mov bx, ACTIVE_HDA_VENDOR
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
    xor rax, rax
    mov al, [INTEL_HDA_PCI_HEADER.bar0]
    and al, 0x06
    jz .bar_32_bits

.bar_64_bits:
    mov eax, [INTEL_HDA_PCI_HEADER.bar1]
    mov dword [ihda_reg_bar + 4], eax

.bar_32_bits:
    mov eax, [INTEL_HDA_PCI_HEADER.bar0]
    and eax, 0xFFFFFFF0
    mov [ihda_reg_bar], eax

.end:
    ret


;
map_intel_hda_interrupt:
    lea rax, [intel_hda_interrupt_handler]
    mov bx, DEFAULT_SEGMENT_SELECTOR
    mov cl, IDT_GATETYPE_INTERRUPT
    xor dl, dl
    movzx r8, byte [INTEL_HDA_PCI_HEADER.intline]
    or r8b, r8b
    jnz .map

    lea rbx, [error_hda_intline_not_valid]
    call error_and_halt

.map:
    add r8, PIC_MASTER_IRQ_VECTOR
    shl r8, 4 ; irqX
    call add_idt_entry
.end:
    ret


;
intel_hda_interrupt_handler:
    ; push rax
    ; push rbx

    ; ; query intel hda to see what interrupt occurred
    ; mov rax, [ihda_reg_bar]
    ; mov ebx, [rax + IHDA_REG_INTERRUPTSTATUS]
    ; and ebx, 1 << 30 ; CIS
    ; jnz .cis_set

.stream_interrupt:
    jmp .error ; not handled for now (also shouldnt happen yet)

; .cis_set:
;     mov bl, [rax + IHDA_REG_RIRBSTS]
;     and bl, 1
;     jz .error

;     call read_rirb_responses
;     or byte [rax + IHDA_REG_RIRBSTS], 1 ; reset RINTFL

; .end:
;     mov al, [INTEL_HDA_PCI_HEADER.intline]
;     call acknowledge_irq
;     pop rbx
;     pop rax
;     iretq

.error:
    lea rbx, [error_hda_interrupt_handler]
    call error_and_halt


; set CRST bit and wait until out of reset
wake_hda_controller:
    ; start wakeup
    mov rax, [ihda_reg_bar]
    or byte [rax + IHDA_REG_GLOBALCONTROL], 0x01

    ; wait til out of reset
.wait:
    mov bl, [rax + IHDA_REG_GLOBALCONTROL]
    and bl, 1
    jz .wait

    ; sleep 521us to allow codecs to turn on
    mov rcx, 25 ; 521us / 21.79us + 1
    call pit_sleep

.end:
    ret


; set corb buffer and reset pointers
setup_corb:
    mov rax, [ihda_reg_bar]

    and byte [rax + IHDA_REG_CORBCTL], 0xFC ; CORBRUN = 0 CMEIE = 0
.dma_off:
    mov bl, [rax + IHDA_REG_CORBCTL]
    and bl, 0x2
    jnz .dma_off ; ensure DMA is off

    mov bl, [rax + IHDA_REG_CORBSIZE]
    shr bl, 4
    cmp bl, 0x4
    je .entries_256

    ; not handled - only support 256 entries for now
    lea rbx, [error_hda_corb_256_entries_str]
    jmp error_and_halt

.entries_256:
    mov bl, [rax + IHDA_REG_CORBSIZE]
    and bl, 0xFC
    or bl, 0x02
    mov byte [rax + IHDA_REG_CORBSIZE], bl ; set CORBSIZE to 256 entries

    lea rbx, [corb_buffer]
    mov [rax + IHDA_REG_CORB_LBA], ebx ; set lower base address

    mov byte [rax + IHDA_REG_CORBWP], 0 ; reset write pointer

    or word [rax + IHDA_REG_CORBRP], 0x8000 ; reset read pointer
.rp_set_1_check:
    mov bx, [rax + IHDA_REG_CORBRP]
    and bx, 0x8000
    jz .rp_set_1_check
    and word [rax + IHDA_REG_CORBRP], 0x7FFF ; reset read pointer
.rp_set_0_check:
    mov bx, [rax + IHDA_REG_CORBRP]
    and bx, 0x8000
    jnz .rp_set_0_check

.end:
    ret


; set rirb buffer and reset pointer
setup_rirb:
    mov rax, [ihda_reg_bar]

    and byte [rax + IHDA_REG_RIRBCTL], 0xF9 ; RIRBDMAEN = 0 RIRBOIC = 0
    and byte [rax + IHDA_REG_RIRBCTL], 0xE ; RINTCTL = 0
.dma_off:
    mov bl, [rax + IHDA_REG_RIRBCTL]
    and bl, 0x2
    jnz .dma_off ; ensure DMA is off

    mov bl, [rax + IHDA_REG_RIRBSIZE]
    shr bl, 4
    cmp bl, 0x4
    je .entries_256

    ; not handled - only support 256 entries for now
    lea rbx, [error_hda_rirb_256_entries_str]
    jmp error_and_halt

.entries_256:
    mov bl, [rax + IHDA_REG_RIRBSIZE]
    and bl, 0xFC
    or bl, 0x02
    mov byte [rax + IHDA_REG_RIRBSIZE], bl ; set RIRBSIZE to 256 entries

    lea rbx, [rirb_buffer]
    mov [rax + IHDA_REG_RIRB_LBA], ebx ; set lower base address

    or word [rax + IHDA_REG_RIRBWP], 0x8000 ; reset write pointer

    mov byte [rax + IHDA_REG_RIRBINTCNT], 128 ; RINTCTL - interrupt after N response/s

.end:
    ret


; turn desired interrupts on, activate corb and rirb dmas, allow unsolicited responses
activate_dmas_and_interrupts:
    mov rax, [ihda_reg_bar]

    mov dword [rax + IHDA_REG_INTERRUPTCONTROL], 0xC0000000 ; GIE = 1, CIE = 1, streams = 0
    and word [rax + IHDA_REG_GLOBALCONTROL], 0xEFF ; UNSOL = 0

    mov bx, [INTEL_HDA_PCI_HEADER.command]
    and bx, 1 << 10
    jz .interrupts_enabled

    ; if this happens, need to write code here to set pci command bit 10 to 0
    lea rbx, [error_hda_interrupts_disabled]
    call error_and_halt

.interrupts_enabled:
    or byte [rax + IHDA_REG_RIRBCTL], 0x2 ; RIRBDMAEN = 1
    or byte [rax + IHDA_REG_CORBCTL], 0x2 ; CORBRUN = 1
.read_back:
    mov bl, [rax + IHDA_REG_CORBCTL]
    and bl, 0x2
    jz .read_back

.end:
    ret


;
query_and_start_codec:
    mov rax, [ihda_reg_bar]
    mov bx, [rax + IHDA_REG_STATESTS]
    or bx, bx
    jnz .statests_set

    lea rbx, [error_hda_codecs_gone]
    call error_and_halt

.statests_set:
    xor ecx, ecx

.query_loop:
    push rbx
    push rcx
    and bx, 1
    jz .next

    call query_node ; start at root node

.next:
    pop rcx
    pop rbx
    add ecx, 1 << 28
    and ecx, 0xF0000000
    shr bx, 1
    cmp bx, 0
    jnz .query_loop

.end:
    ret


; Currently a baseline, only setup for qemu hda-micro codec
;
; IN ecx: ((codec address + 1) << 28) + node index << 20
query_node:
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_NODECOUNT
    call write_corb
    ; call get_rirb_response

    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_FNGROUPTYPE | (1 << 20)
    call write_corb
    ; call get_rirb_response

    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_NODECOUNT | (1 << 20)
    call write_corb
    ; call get_rirb_response

    ; query widget capabilites
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_WIDGETCAP | (2 << 20)
    call write_corb
    ; call get_rirb_response
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_WIDGETCAP | (3 << 20)
    call write_corb
    ; call get_rirb_response
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_WIDGETCAP | (4 << 20)
    call write_corb
    ; call get_rirb_response
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_WIDGETCAP | (5 << 20)
    call write_corb
    ; call get_rirb_response

    ; 3 and 5 pin complexes, 2 out, 4 in

    ; query pin complexes for capabilites
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_PINCAP | (3 << 20)
    call write_corb
    ; call get_rirb_response
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_PINCAP | (5 << 20)
    call write_corb
    ; call get_rirb_response

    ; 3 out pin, 5 in pin

    ; read format, pcm rates, and amp override (node 2)
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_SUPPCMRATES | (2 << 20)
    call write_corb
    ; call get_rirb_response
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_SUPFORMATS | (2 << 20)
    call write_corb
    ; call get_rirb_response
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_GETPARAM | IHDA_NODEDAT_OUTAMPCAP | (2 << 20)
    call write_corb
    ; call get_rirb_response

    ; dont care about pcm rates (use 48kHz anyway), 16 bit audio, 1dB steps, 0x4A steps, 0x4A'th step is 0dB

    ; (hda link -> DAC(2) -> out(3)) 16bit 48kHz audio

    ; set DAC stream format
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_SETFORMAT | IHDA_CONVFORMAT_16 | (2 << 20)
    call write_corb
    ; call get_rirb_response

    ; lower DAC volume and unmute
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_AMPSETGAIN | 0xB002 | (2 << 20)
    call write_corb
    ; call get_rirb_response

    push rcx
    call setup_out_stream
    pop rcx

    ; set DAC stream and lowest channel
    and ecx, 0xF0000000
    movzx eax, byte [ihda_output_stream]
    and al, 0xF
    shl eax, 4
    or ecx, eax
    or ecx, IHDA_NODECMD_SETSTREAMCHAN | 0 | (2 << 20)
    call write_corb
    ; call get_rirb_response

    ; enable out pin
    and ecx, 0xF0000000
    or ecx, IHDA_NODECMD_PINCONTROL | 1 << 6 | (3 << 20)
    call write_corb
    ; call get_rirb_response

    call read_rirb_responses

    ; set run bit to 1
    mov rax, [ihda_reg_bar]
    movzx rbx, byte [ihda_output_stream]
    shl rbx, 5
    or byte [rax + rbx + IHDA_REG_STREAMDESC], 0x2

.end:
    ret


; 16bit 48kHz PCM audio
setup_out_stream:
    mov rax, [ihda_reg_bar]
    mov bx, [rax + IHDA_REG_GLOBALCAPABILITIES]
    shr bx, 4
    shr bl, 4
    mov [ihda_output_stream], bl
    and rbx, 0xF
    shl rbx, 5

    and byte [rax + rbx + IHDA_REG_STREAMDESC], 0xFD ; RUN = 0

    or byte [rax + rbx + IHDA_REG_STREAMDESC], 1 ; SRST = 1 (reset)
.wait_for_reset:
    mov dl, [rax + rbx + IHDA_REG_STREAMDESC]
    and dl, 1
    jz .wait_for_reset

    and byte [rax + rbx + IHDA_REG_STREAMDESC], 0xFE ; SRST = 0 (un reset)
.wait_for_un_reset:
    mov dl, [rax + rbx + IHDA_REG_STREAMDESC]
    and dl, 1
    jnz .wait_for_un_reset

    or byte [rax + rbx + IHDA_REG_STREAMDESC], 0x1C ; enable all ints
    mov dl, [ihda_output_stream]
    shl dl, 4
    or [rax + rbx + IHDA_REG_STREAMDESC + 2], dl ; set STRM to stream number
    push rbx

    ; set stream desc stuff
    lea rdx, [bdl]
    mov [rax + rbx + IHDA_REG_STREAMBDL_LBA], edx ; set lower base address
    shr rdx, 32
    mov [rax + rbx + IHDA_REG_STREAMBDL_UBA], edx ; set upper base address

    call write_bdl_entries

    pop rbx
    dec cl
    mov rax, [ihda_reg_bar]
    mov [rax + rbx + IHDA_REG_STREAMLVI], cl

    mov dword [rax + rbx + IHDA_REG_STREAMCBL], audio_raw.end - audio_raw ; audio needs to fit in a dword

    and word [rax + rbx + IHDA_REG_STREAMFMT], 0x8080
    or word [rax + rbx + IHDA_REG_STREAMFMT], IHDA_CONVFORMAT_16

.end:
    ret


; Returns cl: number of entries
write_bdl_entries:
    xor cl, cl
    lea r8, [audio_raw.end]
    lea rax, [audio_raw]
    mov ebx, 0xFFFFF ; audio input needs to be bigger than this value
    xor edx, edx

.loop:
    mov r9, rax
    add r9, rbx
    cmp r8, r9
    jb .last_entry
    call write_bdl_entry
    add cl, 1
    cmp cl, 0xFF
    je .end
    add rax, rbx
    jmp .loop

.last_entry:
    sub r8, rax
    jz .end
    mov ebx, r8d
    call write_bdl_entry
    inc cl

.end:
    ret


; rax: Address of data
; ebx: Length of data
; edx: IOC
write_bdl_entry:
    lea r9, [bdl]
    movzx r10, byte [bdl_wp]
    shl r10, 4
    movnti [r9 + r10], rax
    movnti [r9 + r10 + 8], ebx
    movnti [r9 + r10 + 12], edx
    add byte [bdl_wp], 1
.end:
    ret


; assume no unsolicited responses
; reads latest response and updates rp accordingly
; Returns rax: response
get_rirb_response:
    mov rax, [ihda_reg_bar]
    mov al, [rax + IHDA_REG_RIRBWP]
    cmp al, [rirb_rp]
    jne .read_response

    lea rbx, [error_hda_no_rirb_response]
    call error_and_halt

.read_response:
    mov [rirb_rp], al
    lea rbx, [rirb_buffer]
    and rax, 0xFF
    shl rax, 3
    mov rax, [rbx + rax]

.end:
    ret


; 31:28 Codec Address
; 27:20 Node Index
; 19:8  Command
; 7:0   Data
; IN ecx: node command
write_corb:
    mov rax, [ihda_reg_bar]
    movzx rbx, byte [rax + IHDA_REG_CORBWP]
    inc bl
    shl bx, 2
    lea rdx, [corb_buffer]
    movnti [rdx + rbx], ecx
    shr bx, 2
    mov [rax + IHDA_REG_CORBWP], bl

.end:
    ret


read_rirb_responses:
    push rax
    push rbx
    push rdx

    mov rax, [ihda_reg_bar]
    mov al, [rax + IHDA_REG_RIRBWP]
    movzx rbx, byte [rirb_rp]

.loop:
    cmp bl, al
    je .set_rp

    inc bl
    shl bx, 3
    lea rdx, [rirb_buffer]
    mov rdx, [rdx + rbx]
    call parse_rirb_response
    shr bl, 3
    jmp .loop

.set_rp:
    mov byte [rirb_rp], bl

.end:
    pop rdx
    pop rbx
    pop rax
    ret


; IN rdx: rirb response
parse_rirb_response:
    push rax
    push rbx
    push rcx
    push rdi
    push r8
    mov rdi, [SIS]
    mov eax, [rdi + SIS_ScreenWidth]
    mov rdi, [rdi + SIS_VRAM]
    shl rax, 6
    add rdi, rax
    add rdi, rax
    add rdi, rax
    add rdi, rax
    movzx rcx, byte [.inc]
.loop:
    add rdi, rax
    loop .loop
    inc byte [.inc]

    mov rbx, rdx
    push rbx
    shr rbx, 32
    call printhex
    pop rbx
    call printhex

    pop r8
    pop rdi
    pop rcx
    pop rbx
    pop rax

.end:
    ret

.inc: db 1


error_hda_not_found_str: db "Error: Intel HDA not found", 0
error_hda_not_hda_str: db "Error: Intel HDA found but not actually", 0
error_hda_io_space_bar_str: db "Error: I/O space BAR not supported", 0
error_hda_intline_not_valid: db "Error: PCI intline value not set or invalid", 0
error_hda_corb_256_entries_str: db "Error: Less than 256 corb entries not supported", 0
error_hda_rirb_256_entries_str: db "Error: Less than 256 rirb entries not supported", 0
error_hda_interrupts_disabled: db "Error: Need to set pci command register bit 10", 0
error_hda_codecs_gone: db "Error: No Intel HDA codecs", 0
error_hda_interrupt_handler: db "Error: Intel HDA interrupt handler broke", 0
error_hda_no_rirb_response: db "Error: Intel HDA CORB command did not get response", 0


ihda_output_stream db 0

corb_entry_size equ 4
rirb_entry_size equ 8
bdl_entry_size equ 16

rirb_rp: db 0
bdl_wp: db 0

    align 128
corb_buffer: times corb_entry_size * 256 db 0 ; ensure writes to this memory are not cached (movnti)
rirb_buffer: times rirb_entry_size * 256 db 0
bdl: times bdl_entry_size * 256 db 0