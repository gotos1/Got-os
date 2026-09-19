AS = nasm
LD = ld

ASFLAGS = -f elf32
LDFLAGS = -m elf_i386 -T linker.ld

all: kernel.elf

boot.o: boot.asm
	$(AS) $(ASFLAGS) boot.asm -o boot.o

kmain.o: kmain.asm
	$(AS) $(ASFLAGS) kmain.asm -o kmain.o

idt.o: idt.asm
	$(AS) $(ASFLAGS) idt.asm -o idt.o

pic.o: pic.asm
	$(AS) $(ASFLAGS) pic.asm -o pic.o

keyboard.o: keyboard.asm
	$(AS) $(ASFLAGS) keyboard.asm -o keyboard.o

screen.o: screen.asm
	$(AS) $(ASFLAGS) screen.asm -o screen.o

serial.o: serial.asm
	$(AS) $(ASFLAGS) serial.asm -o serial.o

filesystem.o: filesystem.asm
	$(AS) $(ASFLAGS) filesystem.asm -o filesystem.o

edit.o: edit.asm
	$(AS) $(ASFLAGS) edit.asm -o edit.o

kernel.elf: boot.o kmain.o idt.o pic.o keyboard.o screen.o serial.o filesystem.o edit.o
	$(LD) $(LDFLAGS) -o kernel.elf boot.o kmain.o idt.o pic.o keyboard.o screen.o serial.o filesystem.o edit.o

clean:
	rm -f *.o kernel.elf gotos.iso
