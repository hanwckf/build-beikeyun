#!/bin/sh

export PATH=/usr/sbin:/usr/bin:/bin:/sbin

apk update && apk add alpine-base haveged dropbear parted e2fsprogs-extra dropbear-scp

echo "root:admin" | chpasswd

for svc in networking urandom swclock; do
	if [ -f ./etc/init.d/$svc ]; then
		ln -sf /etc/init.d/$svc ./etc/runlevels/boot/$svc
	fi
done

for svc in cron crond dropbear haveged ntpd; do
	if [ -f ./etc/init.d/$svc ]; then
		ln -sf /etc/init.d/$svc ./etc/runlevels/default/$svc
	fi
done

sed -i '/^tty[2-6]/d' ./etc/inittab

[ -z "`grep ttyFIQ0 ./etc/inittab`" ] && echo "ttyFIQ0::respawn:/sbin/getty -L ttyFIQ0 1500000 vt100" >> ./etc/inittab
[ -z "`grep ttyFIQ0 ./etc/securetty`" ] && echo "ttyFIQ0" >> ./etc/securetty

sed -i 's/pool.ntp.org/time1.aliyun.com/' ./etc/conf.d/ntpd

echo "alpine" > ./etc/hostname

cat > ./etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
	hostname alpine

EOF
