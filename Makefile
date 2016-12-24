all: netboot.iso

KOS  = toaru-netboot/mod/ac97.ko.xz
KOS += toaru-netboot/mod/ata.ko.xz
KOS += toaru-netboot/mod/debug_shell.ko.xz
KOS += toaru-netboot/mod/ext2.ko.xz
KOS += toaru-netboot/mod/iso9660.ko.xz
KOS += toaru-netboot/mod/lfbvideo.ko.xz
KOS += toaru-netboot/mod/net.ko.xz
KOS += toaru-netboot/mod/packetfs.ko.xz
KOS += toaru-netboot/mod/pcnet.ko.xz
KOS += toaru-netboot/mod/procfs.ko.xz
KOS += toaru-netboot/mod/ps2kbd.ko.xz
KOS += toaru-netboot/mod/ps2mouse.ko.xz
KOS += toaru-netboot/mod/random.ko.xz
KOS += toaru-netboot/mod/rtl.ko.xz
KOS += toaru-netboot/mod/serial.ko.xz
KOS += toaru-netboot/mod/snd.ko.xz
KOS += toaru-netboot/mod/tmpfs.ko.xz
KOS += toaru-netboot/mod/vboxguest.ko.xz
KOS += toaru-netboot/mod/vidset.ko.xz
KOS += toaru-netboot/mod/zero.ko.xz

toaru-netboot/mod/%.ko.xz: $(TOOLCHAIN)/../../hdd/mod/%.ko
	cp $< _tmp.ko
	xz _tmp.ko
	mv _tmp.ko.xz $@

netboot.iso: toaru-netboot/netboot-init.xz toaru-netboot/kernel.xz $(KOS)
	grub-mkrescue -d /usr/lib/grub/i386-pc --compress=xz -o $@ toaru-netboot

toaru-netboot/kernel.xz: $(TOOLCHAIN)/../../toaruos-kernel
	if [ -f toaru-netboot/kernel.xz ]; then rm toaru-netboot/kernel.xz; fi
	cp $< toaru-netboot/kernel
	xz toaru-netboot/kernel

toaru-netboot/netboot-init.xz: netboot-init.c
	if [ -f toaru-netboot/netboot-init.xz ]; then rm toaru-netboot/netboot-init.xz; fi
	i686-pc-toaru-gcc -s -static -Wl,-static -std=c99 -I $(TOOLCHAIN) -o toaru-netboot/netboot-init netboot-init.c -lz -lm
	xz toaru-netboot/netboot-init

