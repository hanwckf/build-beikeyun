#!/bin/bash
# requirements: sfdisk mtools jq

TMPDIR="tmp"
origin="rock64"
target="beikeyun"
output="output"

func_modify() {
	local DISK="$1"
	local DTB="$2"
	[ ! -f "$DISK" -o ! -f "$DTB" ] && echo "file not found!" && exit 1

	SYSTEM_PART_START=$(sfdisk -J ${DISK} |jq .partitiontable.partitions[0].start)
	OFFSET=$(( ${SYSTEM_PART_START} * 512 ))

	echo "SYSTEM_PART_START: $SYSTEM_PART_START"
	echo "OFFSET: $OFFSET"
	mkdir -p ${TMPDIR}

	mcopy -i ${DISK}@@${OFFSET} ::/extlinux/extlinux.conf ./${TMPDIR} || { echo "extlinux.conf dump failed!"; exit 1; }

	sed -i "/^  FDT/c\ \ FDT \/$(basename ${DTB})" ./${TMPDIR}/extlinux.conf
	sed -i '/^  APPEND/s/quiet//' ./${TMPDIR}/extlinux.conf
	if [ -z "`grep panic ./${TMPDIR}/extlinux.conf`" ]; then
		sed -i '/^  APPEND/s/$/ panic=10/' ./${TMPDIR}/extlinux.conf
	fi

	echo "extlinux.conf:"
	echo "#################"
	cat ./${TMPDIR}/extlinux.conf
	echo "#################"
	mdel -i ${DISK}@@${OFFSET} ::/extlinux/extlinux.conf && \
		mcopy -i ${DISK}@@${OFFSET} ./${TMPDIR}/extlinux.conf ::/extlinux/extlinux.conf && \
		echo "extlinux.conf patched!" || { echo "extlinux.conf patch failed!"; exit 1; }

	mdel -i ${DISK}@@${OFFSET} ::/$(basename ${DTB}) 2>/dev/null
	mcopy -i ${DISK}@@${OFFSET} ${DTB} ::/ && echo "dtb patched!" || { echo "dtb patch failed!"; exit 1; }

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
	IMG_NEW=$(basename $(sed "s/${origin}/${target}/" <<< $IMG))
	mv $IMG $output/$IMG_NEW
	xz -T0 -v $output/$IMG_NEW
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
