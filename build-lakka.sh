#!/bin/bash
# requirements: sfdisk mtools jq

TMPDIR="tmp"
origin="ROCK64"
target="beikeyun"
output="output"

func_modify() {
	local DISK="$1"
	local DTB="$2"
	local IDB="$3"
	local UBOOT="$4"
	[ ! -f "$DISK" -o ! -f "$DTB" ] && echo "file not found!" && exit 1

	SYSTEM_PART_START=$(sfdisk -J ${DISK} |jq .partitiontable.partitions[0].start)
	OFFSET=$(( ${SYSTEM_PART_START} * 512 ))

	echo "SYSTEM_PART_START: $SYSTEM_PART_START"
	echo "OFFSET: $OFFSET"
	mkdir -p ${TMPDIR}

	mcopy -no -i ${DISK}@@${OFFSET} ::/extlinux/extlinux.conf ./${TMPDIR} || { echo "extlinux.conf dump failed!"; exit 1; }

	sed -i "/^    fdt/c\ \ \ \ fdt \/$(basename ${DTB})" ./${TMPDIR}/extlinux.conf
	sed -i '/^    append/s/quiet//' ./${TMPDIR}/extlinux.conf
	if [ -z "`grep panic ./${TMPDIR}/extlinux.conf`" ]; then
		sed -i '/^    append/s/$/ panic=10/' ./${TMPDIR}/extlinux.conf
	fi

	echo "extlinux.conf:"
	echo "#################"
	cat ./${TMPDIR}/extlinux.conf
	echo "#################"
	mcopy -no -i ${DISK}@@${OFFSET} ./${TMPDIR}/extlinux.conf ::/extlinux/extlinux.conf && \
		echo "extlinux.conf patched!" || { echo "extlinux.conf patch failed!"; exit 1; }

	mcopy -no -i ${DISK}@@${OFFSET} ${DTB} ::/ && echo "dtb patched: ${DTB}" || { echo "dtb patch failed!"; exit 1; }

	dd if=${IDB} of=${DISK} seek=64 bs=512 conv=notrunc status=noxfer && echo "idb patched: ${IDB}" || { echo "idb patch failed!"; exit 1; }
	dd if=${UBOOT} of=${DISK} seek=16384 bs=512 conv=notrunc status=noxfer && echo "u-boot patched: ${UBOOT}" || { echo "u-boot patch failed!"; exit 1; }
	sync
	rm -rf ${TMPDIR}
}

func_release() {
	local PKG="$1"
	local DTB="$2"
	local IDB="$3"
	local UBOOT="$4"
	[ ! -f "$PKG" -o ! -f "$DTB" ] && echo "file not found!" && exit 1
	IMG="$(sed 's/.gz//' <<< $PKG)"
	gzip -d -k "$PKG"
	func_modify $IMG $DTB $IDB $UBOOT
	IMG_NEW=$(basename $IMG |sed "s/${origin}/${target}/")
	echo "IMG_NEW: $IMG_NEW"
	mv $IMG $output/$IMG_NEW
	if [ -n "$TRAVIS_TAG" ]; then
		xz -f -T0 -v $output/$IMG_NEW
	fi
}

case "$1" in
modify)
	func_modify "$2" "$3" "$4" "$5"
	;;
release)
	func_release "$2" "$3" "$4" "$5"
	;;
*)
	echo "Usage: $0 { modify [img] [dtb] [idb] [u-boot] | release [archive] [dtb] [idb] [u-boot] }"
	exit 1
	;;
esac
