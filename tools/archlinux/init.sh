#!/bin/sh

export PATH=/usr/sbin:/usr/bin:/bin:/sbin

# remove kernel packages
pacman -Rn --noconfirm linux-aarch64 linux-firmware

# set securetty
[ -z "`grep ttyFIQ0 ./etc/securetty`" ] && echo "ttyFIQ0" >> ./etc/securetty

# set /etc/fstab
[ -z "`grep mmcblk0p1 ./etc/fstab`" ] && echo "/dev/mmcblk0p1 / ext4 defaults,noatime,nodiratime,errors=remount-ro 0 1" >> ./etc/fstab

# set ntp server
sed -i '/^#NTP/cNTP=time1.aliyun.com 2001:470:0:50::2' ./etc/systemd/timesyncd.conf

# set sshd_config to allow root login
sed -i '/^#PermitRootLogin/cPermitRootLogin yes' ./etc/ssh/sshd_config

echo "root:admin" |chpasswd

# clean
pacman -Sc --noconfirm
rm -rf ./lib/modules ./lib/firmware ./boot
