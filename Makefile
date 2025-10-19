ASM = nasm
ASM_FLAGS = -f bin

DriveFolder = ./HDA_DRIVE

BootEFI = $(DriveFolder)/efi/boot/bootx64.efi
ExampleProgram = $(DriveFolder)/programs/example_program.bin
ExampleData = $(DriveFolder)/data/example_data.bin

.PHONY: makefile run

all: $(BootEFI) $(ExampleProgram) $(ExampleData)

$(BootEFI): UEFI/efi.asm
	-mkdir $(subst /,\\,$(dir $@))
	$(ASM) $(ASM_FLAGS) -o$@ $^

$(ExampleProgram): src/main.asm
	-mkdir $(subst /,\\,$(dir $@))
	$(ASM) $(ASM_FLAGS) -o$@ $<

$(ExampleData): src/example_data.asm
	-mkdir $(subst /,\\,$(dir $@))
	$(ASM) $(ASM_FLAGS) -o$@ $<

run: all
	qemu-system-x86_64 \
	-bios ovmf-x64/OVMF-pure-efi.fd \
	-drive format=raw,file=fat::rw::HDA_DRIVE \
	-m 100M \
	-monitor stdio
