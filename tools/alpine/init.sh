#!/bin/sh

export PATH=/usr/sbin:/usr/bin:/bin:/sbin

add_svc(){
	runlevel="$1"
	svcs="$2"
	for svc in ${svcs}; do
		if [ -f ./etc/init.d/${svc} ]; then
			ln -sf /etc/init.d/${svc} ./etc/runlevels/${runlevel}/${svc}
		fi
	done
}

apk update --no-progress && \
	apk add --no-progress alpine-base haveged dropbear parted e2fsprogs-extra dropbear-scp tzdata

echo "root:admin" | chpasswd

add_svc "boot" "networking urandom swclock sysctl modules"

add_svc "default" "crond dropbear haveged ntpd"

add_svc "shutdown" "killprocs mount-ro savecache"

sed -i '/^tty[2-6]/d' ./etc/inittab

[ -z "`grep ttyFIQ0 ./etc/inittab`" ] && echo "ttyFIQ0::respawn:/sbin/getty -L ttyFIQ0 1500000 vt100" >> ./etc/inittab
[ -z "`grep ttyFIQ0 ./etc/securetty`" ] && echo "ttyFIQ0" >> ./etc/securetty

sed -i 's/pool.ntp.org/time1.aliyun.com/' ./etc/conf.d/ntpd
ln -sf /usr/share/zoneinfo/Asia/Shanghai ./etc/localtime

echo "alpine" > ./etc/hostname

cat > ./etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
	hostname alpine

EOF

echo "kernel.random.write_wakeup_threshold=1024" > ./etc/sysctl.d/01-random.conf
