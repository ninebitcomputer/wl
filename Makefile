.PHONY: run

%.o: %.asm
	nasm -f elf32 -o $@ $<	

f: f.o
	ld f.o -m elf_i386 -o f

run: f
	./f
