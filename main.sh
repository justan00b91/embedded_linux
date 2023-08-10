#!/bin/bash

KERNEL_VERSION=6.4.9
BUSYBOX_VERSION=1.36.1
ARCH=x86_64

mkdir -p src
cd src

	# Kernel
	echo "Getting latest kernel: $KERNEL_VERSION"
	KERNEL_MAJOR=$(echo $KERNEL_VERSION | sed 's/\([0-9]*\)[^0-9].*/\1/')
	wget https://cdn.kernel.org/pub/linux/kernel/v$KERNEL_MAJOR.x/linux-$KERNEL_VERSION.tar.xz
	echo "Extracting kernel"
	tar xvf linux-$KERNEL_VERSION.tar.xz
	cd linux-$KERNEL_VERSION
		echo "	Generating config for kernel"
		make defconfig
		echo "	Making kernel from config"
		make -j$(nproc) || exit
		cd ..

	# BusyBox
	echo "Getting latest BusyBox: $BUSYBOX_VERSION"
	wget https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
	echo "Extracting busybox"
	tar xvf busybox-$BUSYBOX_VERSION.tar.bz2
	cd busybox-$BUSYBOX_VERSION
		echo "  Generating config for busybox"
		make defconfig
		echo "  Making busybox from config"
		sed 's/^.*CONFIG_STATIC.*$/CONFIG_STATIC=y/g' -i .config
		make -j$(nproc) busybox || exit
	cd ..
cd ..
echo "Copying kernel to currect path"
cp src/linux-$KERNEL_VERSION/arch/$ARCH/boot/bzImage ./

# Initrd
echo "Creating initrd"
mkdir initrd
cd initrd
	mkdir -p bin dev proc sys
	cd bin
		echo "	Setting up symbolic links for busybox"
		cp ../../src/busybox-$BUSYBOX_VERSION/busybox ./
		for prog in $(./busybox --list); do
			ln -s /bin/busybox ./$prog
		done
	cd ..
	echo '#!/bin/sh' > init
	echo 'mount -t sysfs sysfs /sys' >> init
	echo 'mount -t proc proc /proc' >> init
	echo 'mount -t devtmpfs udev /dev' >> init
	echo 'sysctl -w kernel.printk="2 4 1 7"' >> init
	echo '/bin/sh' >> init
	echo 'poweroff -f' >> init
	chmod -R 777 .
	find . | cpio -o -H newc > ../initrd.img
cd ..

# QEMU emulation (optional)
qemu-system-x86_64 -kernel bzImage -initrd initrd.img -nographic -append 'console=ttyS0'

