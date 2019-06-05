DTB_HEADLESS := dtbs/4.4-bsp/headless/rk3328-beikeyun.dtb
DTB_BOX := dtbs/4.4-bsp/box/rk3328-beikeyun.dtb

DL := input
WGET := wget -P $(DL)
AXEL := axel -a -n4 -o $(DL)

OUTPUT := output
TARGETS := armbian libreelec alpine archlinux lakka

.PHONY: help build clean

help:
	@echo "Usage: make build_[system1]=y build_[system2]=y build"
	@echo "available system: $(TARGETS)"

build: $(TARGETS)

clean: $(TARGETS:%=%_clean)
	rm -f $(OUTPUT)/*.img $(OUTPUT)/*.xz

ifeq ($(build_armbian),y)
ARMBIAN_PKGS := Armbian_5.75_Rock64_Ubuntu_bionic_default_4.4.174.7z
ARMBIAN_PKGS += Armbian_5.75_Rock64_Debian_stretch_default_4.4.174.7z

ifneq ($(TRAVIS),)
ARMBIAN_URL_BASE := https://dl.armbian.com/rock64/archive
else
ARMBIAN_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/armbian-releases/rock64/archive
endif

armbian: armbian_dl armbian_release

armbian_dl: $(ARMBIAN_PKGS)

$(ARMBIAN_PKGS):
	( for pkg in $(ARMBIAN_PKGS); do \
		if [ ! -f $(DL)/$$pkg ]; then \
			$(WGET) $(ARMBIAN_URL_BASE)/$$pkg ; \
		fi \
	done )

armbian_release: $(ARMBIAN_PKGS)
	( for pkg in $(ARMBIAN_PKGS); do \
		sudo ./build-armbian.sh release $(DL)/$$pkg $(DTB_HEADLESS) ; \
	done )

armbian_clean:
	( for pkg in $(ARMBIAN_PKGS); do \
		rm -f $(DL)/$$pkg ; \
	done )

else
armbian:
armbian_clean:
endif

ifeq ($(build_libreelec),y)
#LIBREELEC_URL := http://archive.libreelec.tv
LIBREELEC_URL := http://www.gtlib.gatech.edu/pub/LibreELEC

LIBREELEC_PKG := $(shell basename "`hxwls "$(LIBREELEC_URL)/?C=M;O=D" |grep 'rock64.img.gz$$' |head -1`")
libreelec: libreelec_dl libreelec_release

libreelec_clean:
	( if [ -n "$(LIBREELEC_PKG)" ]; then \
		rm -f $(DL)/$(LIBREELEC_PKG) ; \
	fi )

libreelec_dl:
	@( if [ -n "$(LIBREELEC_PKG)" ]; then \
		if [ ! -f $(DL)/$(LIBREELEC_PKG) ]; then \
			$(WGET) "$(LIBREELEC_URL)/$(LIBREELEC_PKG)" ; \
		fi \
	else \
		echo "fetch libreelec dl url fail" ; exit 1 ; \
	fi )

libreelec_release: libreelec_dl
	./build-libreelec.sh release $(DL)/$(LIBREELEC_PKG) $(DTB_BOX)

else
libreelec:
libreelec_clean:
endif

ifeq ($(build_lakka),y)
LAKKA_URL := http://le.builds.lakka.tv/Rockchip.ROCK64.arm
LAKKA_PKG := $(shell basename "`hxwls "$(LAKKA_URL)/?C=M&O=D" |grep 'img.gz$$' |head -1`")
LAKKA_IDB := loader/libreelec/idbloader.bin
LAKKA_UBOOT_PATCH := loader/libreelec/u-boot.bin

lakka: lakka_dl lakka_release

lakka_clean:
	( if [ -n "$(LAKKA_PKG)" ]; then \
		rm -f $(DL)/$(LAKKA_PKG); \
	fi )

lakka_dl:
	( if [ -n "$(LAKKA_PKG)" ]; then \
		if [ ! -f $(DL)/$(LAKKA_PKG) ]; then \
			#$(WGET) "$(LAKKA_URL)/$(LAKKA_PKG)" ; \
			$(AXEL) -q "$(LAKKA_URL)/$(LAKKA_PKG)" ; \
		fi \
	else \
		echo "fetch lakka dl url fail" ; exit 1 ; \
	fi )

lakka_release: lakka_dl
	./build-lakka.sh release $(DL)/$(LAKKA_PKG) $(DTB_BOX) $(LAKKA_IDB) $(LAKKA_UBOOT_PATCH)

else
lakka:
lakka_clean:
endif

ifeq ($(build_alpine),y)
ARMBIAN_PKG := Armbian_5.75_Rock64_Ubuntu_bionic_default_4.4.174.7z
ALPINE_BRANCH := v3.9
ALPINE_VERSION := 3.9.4
ALPINE_PKG := alpine-minirootfs-$(ALPINE_VERSION)-aarch64.tar.gz

ifneq ($(TRAVIS),)
ARMBIAN_URL_BASE := https://dl.armbian.com/rock64/archive
ALPINE_URL_BASE := http://dl-cdn.alpinelinux.org/alpine/$(ALPINE_BRANCH)/releases/aarch64
else
ARMBIAN_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/armbian-releases/rock64/archive
ALPINE_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/alpine/$(ALPINE_BRANCH)/releases/aarch64
endif

alpine: armbian_alpine_dl alpine_dl alpine_release

armbian_alpine_dl: $(ARMBIAN_PKG)

$(ARMBIAN_PKG):
	$(WGET) $(ARMBIAN_URL_BASE)/$(ARMBIAN_PKG)

alpine_dl: $(ALPINE_PKG)

$(ALPINE_PKG):
	$(WGET) $(ALPINE_URL_BASE)/$(ALPINE_PKG)

alpine_release: armbian_alpine_dl alpine_dl
	sudo ./build-alpine.sh release $(DL)/$(ARMBIAN_PKG) $(DTB_HEADLESS) $(DL)/$(ALPINE_PKG)

alpine_clean:
	rm -f $(DL)/$(ARMBIAN_PKG) $(DL)/$(ALPINE_PKG)

else
alpine:
alpine_clean:
endif

ifeq ($(build_archlinux),y)
ARMBIAN_PKG := Armbian_5.75_Rock64_Ubuntu_bionic_default_4.4.174.7z
ARCHLINUX_PKG := ArchLinuxARM-aarch64-latest.tar.gz

ifneq ($(TRAVIS),)
ARMBIAN_URL_BASE := https://dl.armbian.com/rock64/archive
ARCHLINUX_URL_BASE := http://os.archlinuxarm.org/os
else
ARMBIAN_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/armbian-releases/rock64/archive
ARCHLINUX_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/os
endif

archlinux: armbian_archlinux_dl archlinux_dl archlinux_release

armbian_archlinux_dl: $(ARMBIAN_PKG)

$(ARMBIAN_PKG):
	$(WGET) $(ARMBIAN_URL_BASE)/$(ARMBIAN_PKG)

archlinux_dl: $(ARCHLINUX_PKG)

$(ARCHLINUX_PKG):
	$(WGET) $(ARCHLINUX_URL_BASE)/$(ARCHLINUX_PKG)

archlinux_release: armbian_archlinux_dl archlinux_dl
	sudo ./build-archlinux.sh release $(DL)/$(ARMBIAN_PKG) $(DTB_HEADLESS) $(DL)/$(ARCHLINUX_PKG)

archlinux_clean:
	rm -f $(DL)/$(ARMBIAN_PKG) $(DL)/$(ARCHLINUX_PKG)

else
archlinux:
archlinux_clean:
endif
