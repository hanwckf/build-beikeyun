#!/bin/sh

parted /dev/mmcblk0 resizepart 1 Yes 100% && resize2fs /dev/mmcblk0p1 && echo "resize done, please reboot" || echo "resize failed!"
