[BITS 64]
M_OFFS equ 0x00100000
[default rel]

section .header

; see https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
MS_DOS_HEADER:
    dw 0x5A4D       ; magic number 'MZ'
    times 58 db 0   ; rest of the header can remain as zeroes
    dd 0x00000080   ; address of PE_HEADER start (at signature)

PE_HEADER:
    times 64 db 0   ; MS-DOS_STUB, can leave blank
    dd 0x00004550   ; Signature, "PE\0\0"
COFF_FILE_HEADER:
    dw 0x8664       ; machine type: x64
    dw 2            ; number of sections (.text .data)
    dd 0x66CA7400   ; unix epoch time of creation
    dd 0            ; symbol table deprecated for images
    dd 0            ; no symbols in symbol table
    dw OPTIONAL_HEADER_SIZE
    dw 0x1202       ; system file, debug stripped, exe image

OPTIONAL_HEADER:
    dw 0x020b       ; PE32+
    dw 0            ; linker version
    dd SIZEOFALLTEXTSECTIONS
    dd SIZEOFALLDATASECTIONS
    dd SIZEOFALLBSSSECTIONS
    dd start        ; entry point address
    dd start        ; relative offset of entry point in memory (same as entry point)
    dq M_OFFS       ; image base, desired offset in memory (see org)
    SECT_AL equ 2048
    dd SECT_AL      ; section alignment - write decimal as hex
    dd SECT_AL      ; file alignment    - write decimal as hex
    times 16 db 0   ; os, image and subsystem version, 4 bytes reserved
    dd SECT_AL+SIZEOFALLTEXTSECTIONS+SIZEOFALLDATASECTIONS+SIZEOFALLBSSSECTIONS ; image size
    dd SECT_AL      ; size of headers, rounded to multiple of file alignment
    dd 0            ; checksum, not required
    dw 10           ; subsystem: EFI application
    dw 0            ; dll characteristics (N/A)
    dq 0x10000      ; size of stack reserve
    dq 0x10000      ; size of stack commit
    dq 0x10000      ; size of heap reserve
    dq 0            ; size of heap commit
    dd 0            ; reserved (loader flags)
    dd 0            ; number of RVA and sizes
OPTIONAL_HEADER_END:
OPTIONAL_HEADER_SIZE equ OPTIONAL_HEADER_END - OPTIONAL_HEADER

SIZEOFALLTEXTSECTIONS equ SECT_AL
SIZEOFALLDATASECTIONS equ SECT_AL
SIZEOFALLBSSSECTIONS  equ 0

SECTION_TABLE:
.1:
    dq `.text`
    dd SECT_AL
    dd SECT_AL
    dd SECT_AL
    dd SECT_AL
    dd 0
    dd 0
    dw 0
    dw 0
    dd 0xE00000E0   ; section has everything, can be executed, read and written
.2:
    dq `.data`
    dd SECT_AL
    dd 2*SECT_AL
    dd SECT_AL
    dd 2*SECT_AL
    dd 0
    dd 0
    dw 0
    dw 0
    dd 0xC0000040   ; section has init data, can be read and written

times SECT_AL - ($-$$) db 0


section .text follows=.header

    NULL equ 0

start:
    and rsp, 0xFFFFFFFFFFFF0000 ; align to 64 bit

    ; values given by UEFI
    mov [EFI_Handle], rcx
    mov [EFI_SystemTable], rdx

    mov rcx, [rdx + EFI_OFFS_BootServices]
    mov [EFI_BootServices], rcx
    mov rdx, [rcx + EFI_OFFS_RuntimeServices]
    mov [EFI_RuntimeServices], rdx

    ; Boot Services
    mov rdx, [rcx + EFI_OFFS_AllocPool]
    mov [EFI_AllocPool], rdx
    mov rdx, [rcx + EFI_OFFS_FreePool]
    mov [EFI_FreePool], rdx

    ; ConOut
    mov rcx, [EFI_SystemTable]
    mov rdx, [rcx + EFI_OFFS_ConOut]
    mov [EFI_ConOut], rdx
    mov rcx, [rdx + EFI_ConOut_Output]
    mov [EFI_PrintString], rcx

.test_print:
    sub rsp, 32
    mov rcx, [EFI_ConOut]
    lea rdx, [text.test_string]
    call [EFI_PrintString]
    add rsp, 32

    ; setup graphics output protocol
    ; EFI_BOOT_SERVICES.LocateProtocol()
    lea rcx, EFI_GUID_GRAPHICS_OUTPUT_PROTOCOL
    mov rdx, NULL
    lea r8, [GOP_Interface]
    mov rax, [EFI_BootServices]
    sub rsp, 32
    call [rax + EFI_OFFS_LocateProtocol]
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    ; get native mode and number of modes
    mov rcx, [GOP_Interface]
    mov rcx, [rcx + 3*8] ; EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE
    mov rcx, [rcx]
    mov [GOP_NumModes], rcx ; sets both NumModes and CurrentMode (Native originally)

    ; get native resolution
    ; EFI_GRAPHICS_OUTPUT_PROTOCOL.QueryMode()
    mov rcx, [GOP_Interface]
    mov rdx, [GOP_CurrentMode]
    lea r8, [GOP_CurrentModeInfoSize]
    lea r9, [GOP_CurrentModeInfo]
    sub rsp, 32
    call [rcx + 0] ; QueryMode
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    mov rcx, [GOP_CurrentModeInfo]
    mov edx, [rcx + 8] ; V Res
    mov [GOP_Height], edx
    mov edx, [rcx + 32] ; PixelsPerScanLine
    mov [GOP_Width], edx
    mov r12d, [rcx + 12] ; PixelFormat
    cmp r12d, 1
    mov rax, -10
    ja error_print ; program assumes 4 bpp

    ; get VRAM addr
    mov rcx, [GOP_Interface]
    mov rcx, [rcx + 3*8] ; Mode
    mov rdx, [rcx + 3*8] ; FrameBufferBase
    mov [GOP_VRAM], rdx
    mov rdx, [rcx + 4*8] ; FrameBufferSize
    mov [GOP_VRAMSize], rdx

.load_program:
    ; EFI_BOOT_SERVICES.OpenProtocol()
    mov rcx, [EFI_Handle]
    lea rdx, [EFI_GUID_LOADED_IMAGE_PROTOCOL]
    lea r8, [DRIVE_Handle]
    mov r9, [EFI_Handle]
    push qword 1 ; EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL
    sub rsp, 40
    mov rax, [EFI_BootServices]
    call [rax + EFI_OFFS_OpenProtocol]
    cmp rax, EFI_ERR_SUCCESS
    jne error_print
    add rsp, 48

    ; EFI_BOOT_SERVICES.OpenProtocol()
    mov rcx, [DRIVE_Handle]
    mov rcx, [rcx + 24]
    lea rdx, [EFI_GUID_SIMPLE_FILE_SYSTEM_PROTOCOL]
    lea r8, [EFI_SFSP] ; EFI_SIMPLE_FILE_SYSTEM_PROTOCOL
    mov r9, [EFI_Handle]
    push qword 1 ; EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL
    sub rsp, 40
    mov rax, [EFI_BootServices]
    call [rax + EFI_OFFS_OpenProtocol]
    cmp rax, EFI_ERR_SUCCESS
    jne error_print
    add rsp, 48

    ; EFI_SIMPLE_FILE SYSTEM_PROTOCOL.OpenVolume()
    ; -- assume this is the only drive required
    mov rcx, [EFI_SFSP]
    lea rdx, [DRIVE_Root] ; get EFI_FILE_PROTOCOL of volume
    mov rax, [EFI_SFSP]
    sub rsp, 32
    call [rax + 8] ; OpenVolume
    cmp rax, EFI_ERR_SUCCESS
    jne error_print
    add rsp, 32

    ; data file
    sub rsp, 32
    mov rcx, [EFI_ConOut]
    lea rdx, [text.readingFile_string]
    call [EFI_PrintString]
    add rsp, 32

    lea rdx, [DataFileProtocol]
    lea r8, [DataFileName]
    call openFile
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    push qword [DataFileProtocol]
    call getFileSize
    cmp rax, EFI_ERR_SUCCESS
    jne error_print
    mov [DataFileSize], rdx

    add rdx, 8 ; allow for 16 bit alignment
    lea r8, [DataFilePtr]
    call allocPool
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    ; align 16
    mov rax, [DataFilePtr]
    and rax, 0xF
    add [DataFilePtr], rax ; either 0 or 8

    mov rcx, [DataFileProtocol]
    lea rdx, [DataFileSize]
    mov r8, [DataFilePtr]
    call readFile
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    mov rcx, [DataFileProtocol]
    mov rax, [DRIVE_Root]
    sub rsp, 32
    call [rax + 2*8] ; Close
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    ; program file
    sub rsp, 32
    mov rcx, [EFI_ConOut]
    lea rdx, [text.readingFile_string]
    call [EFI_PrintString]
    add rsp, 32

    lea rdx, [DRIVE_ProgramFile]
    lea r8, [ProgramFileName]
    call openFile
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    push qword [DRIVE_ProgramFile]
    call getFileSize
    cmp rax, EFI_ERR_SUCCESS
    jne error_print
    mov [ProgramFileSize], rdx

    lea r8, [ProgramFilePtr]
    call allocPool
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    mov rcx, [DRIVE_ProgramFile]
    lea rdx, [ProgramFileSize]
    mov r8, [ProgramFilePtr]
    call readFile
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    mov rcx, [DRIVE_ProgramFile]
    mov rax, [DRIVE_Root]
    sub rsp, 32
    call [rax + 2*8] ; Close
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

SystemInfoStructSize equ 3*8 + 2*4 + 2*8
    ; allocatePool for SystemInfoStruct
    mov rdx, SystemInfoStructSize
    lea r8, [temp_SystemInfoStructPtr]
    sub rsp, 32
    call allocPool
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    ; fill SystemInfoStruct
    mov rcx, [temp_SystemInfoStructPtr]
    mov qword [rcx], SystemInfoStructSize
    mov rdx, [EFI_SystemTable]
    mov [rcx + 1*8], rdx
    mov rdx, [GOP_VRAM]
    mov [rcx + 2*8], rdx
    mov edx, [GOP_Width]
    mov [rcx + 3*8], rdx
    mov edx, [GOP_Height]
    mov [rcx + 3*8 + 1*4], edx
    mov rdx, [DataFilePtr]
    mov [rcx + 3*8 + 2*4], rdx
    mov rdx, [DataFileSize]
    mov [rcx + 3*8 + 2*4 + 1*8], rdx

    mov rbx, rcx

    ; close volume
    mov rcx, [DRIVE_Root]
    mov rax, rcx
    sub rsp, 32
    call [rax + 2*8] ; Close
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

    ; check file
    mov rcx, [ProgramFilePtr]
    mov rcx, [rcx + 2]
    cmp rcx, [ProgramSignature]
    je .exit_boot_services

.file_error:
    sub rsp, 32
    mov rcx, [EFI_ConOut]
    lea rdx, [text.FILE_ERROR]
    call [EFI_PrintString]
    jmp $

.exit_boot_services:
    lea rcx, [EFI_MM_MapSize]
    mov rdx, [EFI_MemoryMap]
    lea r8, [EFI_MM_MapKey]
    lea r9, [EFI_MM_DescVer]
    push r9
    lea r9, [EFI_MM_DescSize]
    sub rsp, 32
    mov rdi, [EFI_MM_MapSize]
    mov rax, [EFI_BootServices]
    lea rax, [rax + EFI_OFFS_GetMemoryMap]
    call [rax] ; IN/OUT (UINT* MapSize), OUT (*MemoryMap, UINT* MapKey, UINT* DescriptorSize, UINT32* DescriptorVersion)

    add rsp, 40
    cmp eax, EFI_ERR_BUFFER_TOO_SMALL
    je .alloc_MemoryMap
    cmp rax, EFI_ERR_SUCCESS
    je .continue
    jmp error_print

.alloc_MemoryMap:
    mov rdx, [EFI_MM_DescSize]
    shl rdx, 1
    add rdx, [EFI_MM_MapSize]
    lea r8, [EFI_MemoryMap]
    call allocPool
    cmp rax, EFI_ERR_SUCCESS
    je .exit_boot_services
    jmp error_print

.continue:
    mov rcx, [EFI_Handle]
    mov rdx, [EFI_MM_MapKey]
    sub rsp, 32
    mov rax, [EFI_BootServices]
    lea rax, [rax + EFI_OFFS_ExitBootServices] ;  IN (*Handle, UINTN MapKey)
    call [rax]
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    jne error_print

end: ; transfer control to program
    mov rax, [ProgramFilePtr]
    jmp rax


; IN rdx: size
; OUT r8: **void
; Returns rax: EFI_STATUS
allocPool:
    mov rcx, 1 ; type EFI_LOADER_DATA
    sub rsp, 32
    call [EFI_AllocPool]
    add rsp, 32
    ret

; OUT rdx: files EFI_FILE_PROTOCOL
; IN r8: *FileName
; Returns rax: EFI_STATUS
openFile: ; EFI_FILE_PROTOCOL.Open()
    mov rcx, [DRIVE_Root]
    mov r9, 1 ; READ
    push qword NULL
    sub rsp, 32
    call [rcx + 8] ; Open
    add rsp, 40
    ret

; Push qword EFI_FILE_PROTOCOL
; Returns rdx: fileSize
; Returns rax: EFI_STATUS
getFileSize: ; EFI_FILE_PROTOCOL.GetInfo()
    mov rcx, [rsp+8]
    lea rdx, [EFI_GUID_FILE_INFO_ID]
    lea r8, [DRIVE_InfoBufferSize]
    mov r9, [DRIVE_InfoBuffer]
    mov rax, [DRIVE_Root]
    sub rsp, 32
    call [rax + 8*8] ; GetInfo
    add rsp, 32
    cmp eax, EFI_ERR_BUFFER_TOO_SMALL
    je .alloc_GI
    cmp rax, EFI_ERR_SUCCESS
    je .getFileInfo
    ret 8
.alloc_GI:
    mov rdx, [DRIVE_InfoBufferSize]
    lea r8, [DRIVE_InfoBuffer]
    sub rsp, 32
    call allocPool
    add rsp, 32
    cmp rax, EFI_ERR_SUCCESS
    je getFileSize
    ret 8
.getFileInfo:
    mov rdx, [DRIVE_InfoBuffer]
    mov rdx, [rdx + 8] ; FileSize
    push rdx

    mov rcx, [DRIVE_InfoBuffer]
    sub rsp, 32
    call [EFI_FreePool]
    add rsp, 32
    mov qword [DRIVE_InfoBufferSize], 0
    pop rdx
    ret 8

; IN rcx: EFI_FILE_PROTOCOL
; IN rdx: *fileSize
; OUT r8: **void
; Returns rax: EFI_STATUS
readFile: ; EFI_FILE_PROTOCOL.Read()
    mov rax, [DRIVE_Root]
    sub rsp, 32
    call [rax + 4*8] ; Read
    add rsp, 32
    ret

; indicates an error and halts
error_print:
    push rax
    sub rsp, 32
    mov rcx, [EFI_ConOut]
    lea rdx, [text.error_string]
    call [EFI_PrintString]
    add rsp, 32
    pop rax
    cli
    hlt

times SECT_AL - ($-start) db 0 ; ensure no jump or call attempt is made past each SECT_AL division of .text section


section .data follows=.text
data:
text:  ; each char becomes 00xxh when __utf16__ (uefi standard)
    .test_string: dw __utf16__ `Hello World!\r\n\0`
    .error_string: dw __utf16__ `ERROR: Check RAX!\r\n\0`
    .FILE_ERROR: dw __utf16__ `The program signature does not match\r\n\0`
    .readingFile_string: dw __utf16__ `Loading file into memory\r\n\0`

; see https://uefi.org/sites/default/files/resources/UEFI_Spec_2_10_A_Aug8.pdf
    EFI_Handle      dq 0
    EFI_SystemTable dq 0

    EFI_BootServices    dq 0
    EFI_RuntimeServices dq 0
    EFI_ConOut          dq 0

    EFI_AllocPool   dq 0 ; IN (UINT MemoryType, UINT size), OUT (**Buffer)
    EFI_FreePool    dq 0 ; IN (*Buffer)
    EFI_PrintString dq 0 ; IN (*ConOut, *String)

    ; Memory Map (MM) -- may need to copy map elsewhere
    EFI_MemoryMap   dq 0
    EFI_MM_MapSize  dq 0
    EFI_MM_MapKey   dq 0
    EFI_MM_DescSize dq 0
    EFI_MM_DescVer  dq 0
    
    ; Drive Protocol
    DRIVE_Handle        dq 0
    DRIVE_Root          dq 0
    EFI_SFSP            dq 0 ; simple file system protocol
    DRIVE_ProgramFile   dq 0
    DRIVE_InfoBufferSize dq 0
    DRIVE_InfoBuffer    dq 0

    ; Program Stuff
    ProgramFilePtr   dq 0
    ProgramFileSize  dq 0
    ProgramFileName  dw __utf16__ `\\programs\\example_program.bin\0`
    ProgramSignature db 'SIGNATUR' ; 8 bytes checked (can have more or less)

    ; Optional Data Space
    DataFileProtocol    dq 0
    DataFilePtr         dq 0
    DataFileSize        dq 0
    DataFileName        dw __utf16__ `\\data\\example_data.bin\0`

    ; Graphical Output Protocol
    GOP_Interface       dq 0
    GOP_NumModes        dd 0
    GOP_CurrentMode     dd 0
    GOP_CurrentModeInfoSize dq 0
    GOP_CurrentModeInfo dq 0
    GOP_Width           dd 0
    GOP_Height          dd 0
    GOP_VRAM            dq 0
    GOP_VRAMSize        dq 0

    temp_SystemInfoStructPtr dq 0

; GUIDs
    EFI_GUID_GRAPHICS_OUTPUT_PROTOCOL: dd 0x9042a9de
    dw 0x23dc,0x4a38
    db 0x96,0xfb
    db 0x7a,0xde,0xd0,0x80,0x51,0x6a
    EFI_GUID_LOADED_IMAGE_PROTOCOL: dd 0x5B1B31A1
    dw 0x9562,0x11d2
    db 0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B
    EFI_GUID_SIMPLE_FILE_SYSTEM_PROTOCOL: dd 0x0964e5b22
    dw 0x6459,0x11d2
    db 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b
    EFI_GUID_FILE_INFO_ID: dd 0x09576e92
    dw 0x6d3f,0x11d2
    db 0x8e,0x39
    db 0x00,0xa0,0xc9,0x69,0x72,0x3b


; offsets
    ; System Table
    EFI_OFFS_ConOut             equ 64
    EFI_OFFS_RuntimeServices    equ 88
    EFI_OFFS_BootServices       equ 96

    ; Boot Services
    EFI_OFFS_GetMemoryMap       equ 56
    EFI_OFFS_AllocPool          equ 64
    EFI_OFFS_FreePool           equ 72
    EFI_OFFS_ExitBootServices   equ 232
    EFI_OFFS_OpenProtocol       equ 280
    EFI_OFFS_CloseProtocol      equ 288
    EFI_OFFS_LocateHandleBuffer equ 312
    EFI_OFFS_LocateProtocol     equ 320

    ; ConOut
    EFI_ConOut_Output equ 8

; exit_codes
    EFI_ERR_SUCCESS             equ 0
    EFI_ERR_BUFFER_TOO_SMALL    equ 5

times SECT_AL - ($-data) db 0
