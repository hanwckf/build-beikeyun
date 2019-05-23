#!/bin/bash
# requirements: sudo jq sfdisk u-boot-tools

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

mount_point="/mnt/tmp"
tmpdir="tmp"
output="output"

origin="Rock64"
target="beikeyun"

func_umount() {
	umount $mount_point
}

func_mount() {
	local img=$1
	[ ! -f "$img" ] && echo "img file not found!" && return 1
	mkdir -p $mount_point
	start=$(sfdisk -J $img | jq .partitiontable.partitions[0].start)
	offset=$((start * 512))
	mount -o loop,offset=$offset $1 $mount_point
}

func_modify() {
	local dtb=$1
	[ ! -f "$dtb" ] && echo "dtb file not found!" && return 1

	cp -f $dtb $mount_point/boot/

	sed -i '/^verbosity/cverbosity=7' $mount_point/boot/armbianEnv.txt

	if [ -z "`grep fdtfile $mount_point/boot/armbianEnv.txt`" ]; then
		echo "fdtfile=$(basename $dtb)" >> $mount_point/boot/armbianEnv.txt
	fi

	sed -i 's#${prefix}dtb/${fdtfile}#${prefix}/${fdtfile}#' $mount_point/boot/boot.cmd
	mkimage -C none -T script -d $mount_point/boot/boot.cmd $mount_point/boot/boot.scr

	sed -i 's#http://ports.ubuntu.com#https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports#' $mount_point/etc/apt/sources.list
	sed -i 's#http://httpredir.debian.org#https://mirrors.tuna.tsinghua.edu.cn#' $mount_point/etc/apt/sources.list
	sed -i 's#http://security.debian.org#https://mirrors.tuna.tsinghua.edu.cn/debian-security#' $mount_point/etc/apt/sources.list
	sed -i 's#http://apt.armbian.com#https://mirrors.tuna.tsinghua.edu.cn/armbian#' $mount_point/etc/apt/sources.list.d/armbian.list

	rm -f $mount_point/etc/systemd/system/getty.target.wants/serial-getty\@ttyS2.service

	# for armbian dev
:<<!
	if [ -z "`grep eth0 $mount_point/etc/network/interfaces`" ]; then
		cat >> $mount_point/etc/network/interfaces <<- EOF
allow-hotplug eth0
iface eth0 inet dhcp
iface eth0 inet6 auto
		EOF
	fi
	sed -i '/^#NTP=/cNTP=time1.aliyun.com 2001:470:0:50::2' $mount_point/etc/systemd/timesyncd.conf
!
	sync
}

func_release() {
	local dlpkg=$1
	[ ! -f "$dlpkg" ] && echo "dlpkg not found!" && return 1
	rm -rf ${tmpdir}
	7z x -o${tmpdir} $dlpkg && cd ${tmpdir} && sha256sum -c sha256sum.sha && cd - > /dev/null || exit 1

	local dtb=$2
	imgfile="$(ls ${tmpdir}/*.img)"
	echo "origin image file: $imgfile"
	echo "dtb file: $dtb"
	func_mount $imgfile && func_modify $dtb && func_umount

	imgname_new=`basename $imgfile | sed "s/${origin}/${target}/"`
	echo "new image file: $imgname_new"

	mv $imgfile ${output}/${imgname_new}
	if [ -n "$TRAVIS_TAG" ]; then
		xz -f -T0 -v ${output}/${imgname_new}
	fi
	rm -rf ${tmpdir}
}

case "$1" in
umount)
	func_umount
	;;
mount)
	func_mount "$2"
	;;
modify)
	func_mount "$2" && func_modify "$3" && func_umount
	;;
release)
	func_release "$2" "$3"
	;;
*)
	echo "Usage: $0 { mount | umount [img] | modify [img] [dtb] | release [7zpkg] [dtb] }"
	exit 1
	;;
esac
