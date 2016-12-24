all: netboot.iso

netboot.iso: toaru-netboot/netboot-init.xz toaru-netboot/kernel.xz
	grub-mkrescue -d /usr/lib/grub/i386-pc --compress=xz -o $@ toaru-netboot

toaru-netboot/kernel.xz: $(TOOLCHAIN)/../../toaruos-kernel
	if [ -f toaru-netboot/kernel.xz ]; then rm toaru-netboot/kernel.xz; fi
	cp $< toaru-netboot/kernel
	xz toaru-netboot/kernel

toaru-netboot/netboot-init.xz: netboot-init.c
	if [ -f toaru-netboot/netboot-init.xz ]; then rm toaru-netboot/netboot-init.xz; fi
	i686-pc-toaru-gcc -static -Wl,-static -std=c99 -I $(TOOLCHAIN) -o toaru-netboot/netboot-init netboot-init.c -lz -lm
	xz toaru-netboot/netboot-init

