.PHONY: default all clean

default: STAGE2.BIN

STAGE2.BIN: a20.asm disk.asm fat.asm longmode.asm main.asm util.asm video.asm
	nasm -f bin main.asm -o STAGE2.BIN

clean:
	rm STAGE2.BIN