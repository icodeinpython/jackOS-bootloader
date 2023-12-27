.PHONY: default all clean

default: all

all: KERNEL.BIN

KERNEL.BIN: kernel.asm
	nasm -f bin kernel.asm -o KERNEL.BIN