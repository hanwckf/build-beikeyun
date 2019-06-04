#!/bin/sh

if [ -e /root/.need_resize ]; then 
echo "d
n
p
1
32768
-0
w" | fdisk /dev/mmcblk0 && resize2fs /dev/mmcblk0p1 && echo "resize done, please reboot" || echo "resize failed!"
	rm -f /root/.need_resize
fi
