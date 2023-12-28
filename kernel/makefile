.PHONY: default all clean

default: all

all: KERNEL.BIN

KERNEL.BIN: kernel.asm
	nasm -f elf64 kernel.asm -o kernel.o
	x86_64-elf-ld kernel.o -o KERNEL.BIN -O2 -nostdlib -Tlinker.ld
#	x86_64-elf-gcc -c kernel.c -o kernel.o -std=gnu99 -ffreestanding -O2
#	x86_64-elf-gcc -T linker.ld -o KERNEL.BIN -ffreestanding -O2 -nostdlib kernel.o load.o