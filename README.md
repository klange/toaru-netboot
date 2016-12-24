# Netboot ToaruOS

Using the `netboot-init` in this repository, you can build ToaruOS images that download, decompress, and mount root filesystem images live.

## How it works

`netboot-init` is a mashup of `init`, `fetch`, `ungz`, and `mount` that can replace a normal `init` binary in ToaruOS. Combined with a kernel, modules, and bootloader, you can build a bootable image inder 3MB that downloads from a remote server before continuing the boot process. A gzipped image is downloaded and decompressed in memory, that image is then mounted, and its own `/bin/init` is run.

To use your own server as a netboot source, you need to change the URL from which the netboot image is downloaded and generate a ramdisk (it's the same ramdisk image used for CDs, so you can use `make _cdrom/ramdisk.img.gz` from a CD build environment, but be sure to clean up afterwards).

## tl;dr

    qemu-system-i386 -vga std -m 512 -cdrom http://toaruos.org/netboot.iso -M accel=kvm:tcg \
      -soundhw ac97 -net user -net nic,model=rtl8139 -serial stdio

![screenshot](http://i.imgur.com/EtESKdW.png)
