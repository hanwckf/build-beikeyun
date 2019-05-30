#!/bin/bash
# requirements: sudo jq sfdisk u-boot-tools qemu bimfmt_misc
# require armbian kernel and u-boot

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

armbian_mount_point="/mnt/armbian_rootfs"
rootfs_mount_point="/mnt/alpine_rootfs"

tmpdir="tmp"
output="output"

origin="minirootfs"
target="beikeyun"

rootsize=150
ROOTOFFSET=32768

qemu_static="./tools/alpine/qemu-aarch64-static"

func_umount_armbian() {
	umount $armbian_mount_point
}

func_mount_armbian() {
	local img=$1
	local mount_point=$2
	[ ! -f "$img" ] && echo "img file not found!" && return 1
	start=$(sfdisk -J $img | jq .partitiontable.partitions[0].start)
	offset=$((start * 512))
	mkdir -p $mount_point
	mount -o loop,offset=$offset $1 $mount_point
}

func_generate() {
	local armbian_img=$1
	local dtb=$2
	local rootfs=$3
	local img_new=${4:-alpine.img}

	[ ! -f "$dtb" ] && echo "dtb file not found!" && return 1
	[ ! -f "$rootfs" ] && echo "alpine rootfs file not found!" && return 1
	[ ! -f "$armbian_img" ] && echo "armbian img file not found!" && return 1

	# create ext4 rootfs img
	mkdir -p ${tmpdir}
	echo "create ext4 rootfs, size: ${rootsize}M"
	dd if=/dev/zero bs=1M status=none count=$rootsize of=$tmpdir/rootfs.img
	mkfs.ext4 -q -m 2 $tmpdir/rootfs.img

	# mount rootfs
	mkdir -p $rootfs_mount_point
	mount -o loop $tmpdir/rootfs.img $rootfs_mount_point

	# extract alpine rootfs
	echo "extract alpine rootfs($rootfs) to $rootfs_mount_point"
	tar xf $rootfs -C $rootfs_mount_point

	# mount armbian rootfs
	func_mount_armbian $armbian_img $armbian_mount_point

	# get /boot /lib/modules /lib/firmware
	echo "copy /boot,/lib/modules,/lib/firmware from armbian"
	cp -rf $armbian_mount_point/boot $rootfs_mount_point/boot
	cp -rf $armbian_mount_point/lib/modules $rootfs_mount_point/lib/modules
	cp -rf $armbian_mount_point/lib/firmware $rootfs_mount_point/lib/firmware

	#umount armbian rootfs
	func_umount_armbian

	# patch /boot
	echo "patch /boot"
	cp -f $dtb $rootfs_mount_point/boot/
	sed -i '/^verbosity/cverbosity=7' $rootfs_mount_point/boot/armbianEnv.txt
	sed -i '/^rootdev/crootdev=\/dev\/mmcblk0p1' $rootfs_mount_point/boot/armbianEnv.txt
	if [ -z "`grep fdtfile $rootfs_mount_point/boot/armbianEnv.txt`" ]; then
		echo "fdtfile=$(basename $dtb)" >> $rootfs_mount_point/boot/armbianEnv.txt
	fi
	if [ -z "`grep extraargs $rootfs_mount_point/boot/armbianEnv.txt`" ]; then
		echo "extraargs=rw console=ttyFIQ0,1500000" >> $rootfs_mount_point/boot/armbianEnv.txt
	fi
	sed -i 's#${prefix}dtb/${fdtfile}#${prefix}/${fdtfile}#' $rootfs_mount_point/boot/boot.cmd
	mkimage -C none -T script -d $rootfs_mount_point/boot/boot.cmd $rootfs_mount_point/boot/boot.scr

	# change mirrors
	if [ -z "$TRAVIS" ]; then
		sed -i 's#http://dl-cdn.alpinelinux.org#https://mirrors.tuna.tsinghua.edu.cn#' $rootfs_mount_point/etc/apk/repositories
		echo "nameserver 119.29.29.29" > $rootfs_mount_point/etc/resolv.conf
	else
		echo "nameserver 8.8.8.8" > $rootfs_mount_point/etc/resolv.conf
	fi

	# chroot to alpine rootfs
	echo "configure binfmt to chroot"
	modprobe binfmt_misc
	if [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
		qemu="`grep 'interpreter' /proc/sys/fs/binfmt_misc/qemu-aarch64 |cut -d ' ' -f2`"
		echo "copy $qemu to $rootfs_mount_point/$qemu"
		cp $qemu $rootfs_mount_point/$qemu
	elif [ -e /proc/sys/fs/binfmt_misc/register ]; then
		echo -1 > /proc/sys/fs/binfmt_misc/status
		echo ":arm64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:OC" > /proc/sys/fs/binfmt_misc/register
		echo "copy $qemu_static to $rootfs_mount_point/usr/bin/"
		cp $qemu_static $rootfs_mount_point/usr/bin/qemu-aarch64-static
	else
		echo "Could not configure binfmt for qemu!" && exit 1
	fi

	cp ./tools/alpine/init.sh $rootfs_mount_point/init.sh
	echo "chroot to alpine rootfs"
	chroot $rootfs_mount_point /init.sh
	rm -f $rootfs_mount_point/init.sh
	[ -n "$qemu" ] && rm -f $rootfs_mount_point/$qemu || rm -f $rootfs_mount_point/usr/bin/qemu-aarch64-static

	if [ -z "$TRAVIS" ]; then
		sed -i 's/https/http/' $rootfs_mount_point/etc/apk/repositories
	else
		sed -i 's#http://dl-cdn.alpinelinux.org#http://mirrors.tuna.tsinghua.edu.cn#' $rootfs_mount_point/etc/apk/repositories
	fi

	# add resize script
	cp ./tools/alpine/resizemmc.sh $rootfs_mount_point/sbin/resizemmc.sh
	cp ./tools/alpine/resizemmc $rootfs_mount_point/etc/init.d/resizemmc
	ln -sf /etc/init.d/resizemmc $rootfs_mount_point/etc/runlevels/default/resizemmc
	touch $rootfs_mount_point/root/.need_resize

	umount $rootfs_mount_point
	# generate img
	echo "copy boot header from armbian img"
	dd if=$armbian_img bs=512 count=$ROOTOFFSET status=none of=${output}/${img_new}
	cat $tmpdir/rootfs.img >> ${output}/${img_new}
	parted -s ${output}/${img_new} -- mklabel msdos
	parted -s ${output}/${img_new} -- mkpart primary ext4 ${ROOTOFFSET}s -1s
	sync
	rm -f $tmpdir/rootfs.img
}

func_release() {
	local dlpkg=$1
	local dtb=$2
	local rootfs=$3

	[ ! -f "$dlpkg" ] && echo "dlpkg not found!" && return 1
	rm -rf ${tmpdir}
	7z x -o${tmpdir} $dlpkg && cd ${tmpdir} && sha256sum -c sha256sum.sha && cd - > /dev/null || exit 1

	armbian_img="$(ls ${tmpdir}/*.img)"
	echo "alpine rootfs: $rootfs"
	echo "armbian image file: $armbian_img"
	echo "dtb file: $dtb"

	imgname_new="`basename $rootfs | sed "s/${origin}/${target}/" | sed 's/.tar.gz$/.img/'`"

	func_generate $armbian_img $dtb $rootfs $imgname_new
	echo "new image file: $imgname_new"

	if [ -n "$TRAVIS_TAG" ]; then
		xz -f -T0 -v ${output}/${imgname_new}
	fi
	rm -rf ${tmpdir}
}

case "$1" in
generate)
	func_generate "$2" "$3" "$4" 
	;;
release)
	func_release "$2" "$3" "$4"
	;;
*)
	echo "Usage: $0 { generate [armbian-img] [dtb] [rootfs] | release [armbian-7zpkg] [dtb] [rootfs] }"
	exit 1
	;;
esac
