.PHONY: clean, .force-rebuild default
all: hdd.img

bootsector/boot.bin: bootsector/boot.asm .force-rebuild
	pushd bootsector && make && popd

stage2/STAGE2.BIN: stage2/a20.asm stage2/disk.asm stage2/fat.asm stage2/longmode.asm stage2/main.asm stage2/util.asm stage2/video.asm
	pushd stage2 && make && popd

kernel/KERNEL.BIN: kernel/kernel.asm
	pushd kernel && make && popd

run: hdd.img
	bochs -q

hdd.img: bootsector/boot.bin stage2/STAGE2.BIN kernel/KERNEL.BIN
	dd if=/dev/zero of=hdd.img bs=512 count=4050
	mkfs.fat -F12 hdd.img
	dd if=bootsector/boot.bin of=hdd.img conv=notrunc
	sudo mount hdd.img mnt
	sudo cp stage2/STAGE2.BIN mnt/STAGE2
	sudo touch mnt/TESTTEST.TXT
	sudo sh -c 'echo "helloWorld" > mnt/TESTTEST.TXT'
	sudo cp kernel/KERNEL.BIN mnt
	sync

clean:
	sudo umount mnt &> /dev/null || true
	rm hdd.img stage2/STAGE2.BIN bootsector/boot.bin &> /dev/null || true
