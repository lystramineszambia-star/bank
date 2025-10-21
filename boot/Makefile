NASM ?= nasm
LD   ?= ld
QEMU ?= qemu-system-i386

IMG        ?= disk.img
STAGE2_SECT?= 32
KERNEL_SECT?= 256

all: stage1.bin stage2.bin kernel.elf image

stage1.bin: stage1.asm
	$(NASM) -f bin $< -o $@

stage2.bin: stage2_elf.asm
	$(NASM) -f bin $< -o $@
	@sz=$$(stat -c%s stage2.bin 2>/dev/null || stat -f%z stage2.bin); \
	max=$$(( $(STAGE2_SECT) * 512 )); \
	if [ $$sz -gt $$max ]; then \
	  echo "ERROR: stage2.bin ($$sz) > $(STAGE2_SECT) sectors ($$max)"; exit 1; fi

kernel.o: kernel32.asm
	$(NASM) -f elf32 $< -o $@

kernel.elf: kernel.o linker.ld
	$(LD) -m elf_i386 -T linker.ld -nostdlib -static -o $@ kernel.o

image: stage1.bin stage2.bin kernel.elf
	dd if=/dev/zero of=$(IMG) bs=512 count=2880 2>/dev/null
	d if=stage1.bin of=$(IMG) conv=notrunc 2>/dev/null
	d if=stage2.bin of=$(IMG) bs=512 seek=1 conv=notrunc 2>/dev/null
	d if=kernel.elf of=$(IMG) bs=512 seek=33 conv=notrunc 2>/dev/null
	@echo "Disk layout:"
	@echo "  LBA 0    : stage1 (MBR)"
	@echo "  LBA 1-32 : stage2"
	@echo "  LBA 33+  : kernel.elf (raw ${KERNEL_SECT} sectors max)"

run: image
	$(QEMU) -drive file=$(IMG),format=raw

clean:
	rm -f *.bin *.o *.elf $(IMG)