#!/bin/bash
# requirements: sfdisk mtools jq squashfs-tools

TMPDIR="tmp"
origin="rock64"
target="beikeyun"
output="output"

func_modify() {
	local DISK="$1"
	local DTB="$2"
	[ ! -f "$DISK" -o ! -f "$DTB" ] && echo "file not found!" && exit 1

	# get offset of 1st partition
	SYSTEM_PART_START=$(sfdisk -J ${DISK} |jq .partitiontable.partitions[0].start)
	OFFSET=$(( ${SYSTEM_PART_START} * 512 ))

	echo "SYSTEM_PART_START: $SYSTEM_PART_START"
	echo "OFFSET: $OFFSET"
	mkdir -p ${TMPDIR}

	# patch extlinux.conf
	mcopy -no -i ${DISK}@@${OFFSET} ::/extlinux/extlinux.conf ./${TMPDIR} || { echo "extlinux.conf dump failed!"; exit 1; }
	sed -i "/^  FDT/c\ \ FDT \/$(basename ${DTB})" ./${TMPDIR}/extlinux.conf
	sed -i '/^  APPEND/s/quiet//' ./${TMPDIR}/extlinux.conf
	if [ -z "`grep panic ./${TMPDIR}/extlinux.conf`" ]; then
		sed -i '/^  APPEND/s/$/ panic=10/' ./${TMPDIR}/extlinux.conf
	fi

	echo "extlinux.conf:"
	echo "#################"
	cat ./${TMPDIR}/extlinux.conf
	echo "#################"
	mcopy -no -i ${DISK}@@${OFFSET} ./${TMPDIR}/extlinux.conf ::/extlinux/extlinux.conf && \
		echo "extlinux.conf patched!" || { echo "extlinux.conf patch failed!"; exit 1; }

	# copy dtb
	mcopy -no -i ${DISK}@@${OFFSET} ${DTB} ::/ && echo "dtb patched: ${DTB}" || { echo "dtb patch failed!"; exit 1; }

	# add /opt to SYSTEM.squashfs for entware
	mcopy -no -i ${DISK}@@${OFFSET} ::/SYSTEM ./${TMPDIR} || { echo "SYSTEM.squashfs dump failed!"; exit 1; }
	mkdir -p ./${TMPDIR}/new/opt && mksquashfs ./${TMPDIR}/new ./${TMPDIR}/SYSTEM -all-root -no-progress
	# recalc md5sum
	md5sum ${TMPDIR}/SYSTEM | sed "s#${TMPDIR}/SYSTEM#target/SYSTEM#" > ${TMPDIR}/SYSTEM.md5
	mcopy -no -i ${DISK}@@${OFFSET} ./${TMPDIR}/SYSTEM ::/
	mcopy -no -i ${DISK}@@${OFFSET} ./${TMPDIR}/SYSTEM.md5 ::/
	echo "SYSTEM.squashfs patched!"

	sync
	rm -rf ${TMPDIR}
}

func_release() {
	local PKG="$1"
	local DTB="$2"
	[ ! -f "$PKG" -o ! -f "$DTB" ] && echo "file not found!" && exit 1
	IMG="$(sed 's/.gz//' <<< $PKG)"
	gzip -d -k "$PKG"
	func_modify $IMG $DTB
	IMG_NEW=$(basename $IMG |sed "s/${origin}/${target}/")
	echo "IMG_NEW: $IMG_NEW"
	mv $IMG $output/$IMG_NEW
	if [ -n "$TRAVIS_TAG" ]; then
		xz -f -T0 -v $output/$IMG_NEW
	fi
}

case "$1" in
modify)
	func_modify "$2" "$3"
	;;
release)
	func_release "$2" "$3"
	;;
*)
	echo "Usage: $0 { modify [img] [dtb] | release [archive] [dtb] }"
	exit 1
	;;
esac
