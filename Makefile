.PHONY: run clean

clean:
	rm -f f
	rm -f *.o

%.o: %.asm common.asm
	nasm -f elf32 -o $@ $<	

f: f.o stream.o utility.o
	ld f.o stream.o utility.o -m elf_i386 -o f

run: f
	./f
