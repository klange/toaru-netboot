all: netboot.iso

KOS  = toaru-netboot/mod/ac97.ko.xz
KOS += toaru-netboot/mod/ata.ko.xz
KOS += toaru-netboot/mod/ataold.ko.xz
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
KOS += toaru-netboot/mod/e1000.ko.xz
KOS += toaru-netboot/mod/serial.ko.xz
KOS += toaru-netboot/mod/snd.ko.xz
KOS += toaru-netboot/mod/tmpfs.ko.xz
KOS += toaru-netboot/mod/vboxguest.ko.xz
KOS += toaru-netboot/mod/vidset.ko.xz
KOS += toaru-netboot/mod/vmware.ko.xz
KOS += toaru-netboot/mod/zero.ko.xz

GRUB_MODS  = _grub_support/biosdisk.mod
GRUB_MODS += _grub_support/iso9660.mod
GRUB_MODS += _grub_support/part_sunpc.mod
GRUB_MODS += _grub_support/bitmap.mod
GRUB_MODS += _grub_support/loadenv.mod
GRUB_MODS += _grub_support/pci.mod
GRUB_MODS += _grub_support/bitmap_scale.mod
GRUB_MODS += _grub_support/lsapm.mod
GRUB_MODS += _grub_support/png.mod
GRUB_MODS += _grub_support/boot.mod
GRUB_MODS += _grub_support/ls.mod
GRUB_MODS += _grub_support/priority_queue.mod
GRUB_MODS += _grub_support/bufio.mod
GRUB_MODS += _grub_support/minicmd.mod
GRUB_MODS += _grub_support/read.mod
GRUB_MODS += _grub_support/configfile.mod
GRUB_MODS += _grub_support/mmap.mod
GRUB_MODS += _grub_support/relocator.mod
GRUB_MODS += _grub_support/crypto.mod
GRUB_MODS += _grub_support/multiboot.mod
GRUB_MODS += _grub_support/terminal.mod
GRUB_MODS += _grub_support/datetime.mod
GRUB_MODS += _grub_support/net.mod
GRUB_MODS += _grub_support/test.mod
GRUB_MODS += _grub_support/disk.mod
GRUB_MODS += _grub_support/normal.mod
GRUB_MODS += _grub_support/trig.mod
GRUB_MODS += _grub_support/echo.mod
GRUB_MODS += _grub_support/part_acorn.mod
GRUB_MODS += _grub_support/vbe.mod
GRUB_MODS += _grub_support/extcmd.mod
GRUB_MODS += _grub_support/part_amiga.mod
GRUB_MODS += _grub_support/vga.mod
GRUB_MODS += _grub_support/font.mod
GRUB_MODS += _grub_support/part_apple.mod
GRUB_MODS += _grub_support/video_bochs.mod
GRUB_MODS += _grub_support/fshelp.mod
GRUB_MODS += _grub_support/part_bsd.mod
GRUB_MODS += _grub_support/video_cirrus.mod
GRUB_MODS += _grub_support/gcry_crc.mod
GRUB_MODS += _grub_support/part_dfly.mod
GRUB_MODS += _grub_support/video_colors.mod
GRUB_MODS += _grub_support/gettext.mod
GRUB_MODS += _grub_support/part_dvh.mod
GRUB_MODS += _grub_support/video_fb.mod
GRUB_MODS += _grub_support/gfxmenu.mod
GRUB_MODS += _grub_support/part_gpt.mod
GRUB_MODS += _grub_support/video.mod
GRUB_MODS += _grub_support/gfxterm.mod
GRUB_MODS += _grub_support/part_msdos.mod
GRUB_MODS += _grub_support/xzio.mod
GRUB_MODS += _grub_support/gzio.mod
GRUB_MODS += _grub_support/part_plan.mod
GRUB_MODS += _grub_support/help.mod
GRUB_MODS += _grub_support/part_sun.mod

GRUB_FILES  = toaru-netboot/boot/grub/grub.cfg
GRUB_FILES += toaru-netboot/boot/grub/menus.cfg
GRUB_FILES += toaru-netboot/boot/grub/modules.cfg
GRUB_FILES += toaru-netboot/boot/grub/theme.txt

toaru-netboot/mod/%.ko.xz: $(TOOLCHAIN)/../../hdd/mod/%.ko
	@cp $< _tmp.ko
	@xz _tmp.ko
	@mv _tmp.ko.xz $@

_grub_support/%.mod: /usr/lib/grub/i386-pc/%.mod | _grub_support
	@cp $< $@

_grub_support: /usr/lib/grub/i386-pc
	if [ -d _grub_support ]; then rm -r _grub_support; fi
	cp -r /usr/lib/grub/i386-pc _grub_support
	rm _grub_support/*.mod

netboot.iso: toaru-netboot/netboot-init.xz toaru-netboot/kernel.xz $(KOS) $(GRUB_MODS) $(GRUB_FILES)
	grub-mkrescue -d _grub_support --compress=xz -o $@ toaru-netboot

toaru-netboot/kernel.xz: $(TOOLCHAIN)/../../toaruos-kernel
	if [ -f toaru-netboot/kernel.xz ]; then rm toaru-netboot/kernel.xz; fi
	cp $< toaru-netboot/kernel
	xz toaru-netboot/kernel

toaru-netboot/netboot-init.xz: netboot-init.c
	if [ -f toaru-netboot/netboot-init.xz ]; then rm toaru-netboot/netboot-init.xz; fi
	i686-pc-toaru-gcc -s -static -Wl,-static -std=c99 -I $(TOOLCHAIN) -o toaru-netboot/netboot-init netboot-init.c -lz -lm
	xz toaru-netboot/netboot-init

