ASM = nasm
ASM_FLAGS = -f bin

DriveFolder = ./HDA_DRIVE

BootEFI = $(DriveFolder)/efi/boot/bootx64.efi
PEAR = $(DriveFolder)/programs/pear.bin
UTIL_FUNCTIONS = ./src/util_functions

.PHONY: makefile run
.SUFFIXES:

all: $(BootEFI) $(PEAR)

$(BootEFI): UEFI/efi.asm
	-mkdir $(subst /,\\,$(dir $@))
	$(ASM) $(ASM_FLAGS) -o$@ $^

$(PEAR): src/main.asm src/*.asm $(UTIL_FUNCTIONS)/include.asm $(UTIL_FUNCTIONS)/*/*.asm
	-mkdir $(subst /,\\,$(dir $@))
	$(ASM) $(ASM_FLAGS) -dFUNCTIONS=\"$(UTIL_FUNCTIONS)/\" -o$@ $<

run: all
	qemu-system-x86_64 \
	-bios ovmf-x64/OVMF-pure-efi.fd \
	-drive format=raw,file=fat::rw::HDA_DRIVE \
	-m 100M \
	-monitor stdio \
	-audiodev dsound,id=ds \
	-device ich9-intel-hda,debug=5 -device hda-micro,audiodev=ds,debug=5 \
	-no-reboot -d cpu_reset,int -D log.txt
