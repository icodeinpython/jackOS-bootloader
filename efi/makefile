.PHONY: all default clean qemu

default: hdd.img

hdd.img: loader
	dd if=/dev/zero of=boot.img bs=1M count=512
	mkfs.vfat boot.img
	mkdir -p mnt
	sudo mount boot.img mnt &> /dev/null || true
	sudo mkdir -p mnt/efi/boot
	sudo cp build/bootx64.efi mnt/efi/boot
	sudo cp kernel.elf mnt/kernel.elf
	sudo umount mnt

loader:
	pushd src && make && popd

qemu: hdd.img
	sudo qemu-system-x86_64 -drive file=/usr/share/OVMF/x64/OVMF_CODE.fd,format=raw,if=pflash -cdrom boot.img -m 1G -serial stdio

clean:
	rm boot.img
	pushd src && make clean && popd