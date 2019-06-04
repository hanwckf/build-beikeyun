DTB_HEADLESS := dtbs/4.4-bsp/headless/rk3328-beikeyun.dtb
DTB_BOX := dtbs/4.4-bsp/box/rk3328-beikeyun.dtb

OUTPUT := output
TARGETS := armbian libreelec alpine lakka

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
		if [ ! -f $$pkg ]; then \
			wget $(ARMBIAN_URL_BASE)/$$pkg ; \
		fi \
	done )

armbian_release: $(ARMBIAN_PKGS)
	( for pkg in $(ARMBIAN_PKGS); do \
		sudo ./build-armbian.sh release $$pkg $(DTB_HEADLESS) ; \
	done )

armbian_clean:
	rm -f $(ARMBIAN_PKGS)

else
armbian:
armbian_clean:
endif

ifeq ($(build_libreelec),y)
LIBREELEC_PKG := $(shell basename `hxwls "http://archive.libreelec.tv/?C=M;O=D" |grep 'rock64.img.gz$$' |head -1`)

libreelec: libreelec_dl libreelec_release

libreelec_clean:
	rm -f $(LIBREELEC_PKG)

libreelec_dl:
	( if [ -n "$(LIBREELEC_PKG)" ]; then \
		if [ ! -f $(LIBREELEC_PKG) ]; then \
			wget "http://archive.libreelec.tv/$(LIBREELEC_PKG)" ; \
		fi \
	else \
		echo "fetch libreelec dl url fail" ; exit 1 ; \
	fi )

libreelec_release: libreelec_dl
	./build-libreelec.sh release $(LIBREELEC_PKG) $(DTB_BOX)

else
libreelec:
libreelec_clean:
endif

ifeq ($(build_lakka),y)
LAKKA_PKG := $(shell basename `hxwls "http://le.builds.lakka.tv/Rockchip.ROCK64.arm/?C=M&O=D" |grep 'img.gz$$' |head -1`)
LAKKA_IDB := loader/libreelec/idbloader.bin
LAKKA_UBOOT_PATCH := loader/libreelec/u-boot.bin

lakka: lakka_dl lakka_release

lakka_clean:
	rm -f $(LAKKA_PKG)

lakka_dl:
	( if [ -n "$(LAKKA_PKG)" ]; then \
		if [ ! -f $(LAKKA_PKG) ]; then \
			wget "http://le.builds.lakka.tv/Rockchip.ROCK64.arm/$(LAKKA_PKG)" ; \
		fi \
	else \
		echo "fetch lakka dl url fail" ; exit 1 ; \
	fi )

lakka_release: lakka_dl
	./build-lakka.sh release $(LAKKA_PKG) $(DTB_BOX) $(LAKKA_IDB) $(LAKKA_UBOOT_PATCH)

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
	wget $(ARMBIAN_URL_BASE)/$(ARMBIAN_PKG)

alpine_dl: $(ALPINE_PKG)

$(ALPINE_PKG):
	wget $(ALPINE_URL_BASE)/$(ALPINE_PKG)

alpine_release: armbian_alpine_dl alpine_dl
	sudo ./build-alpine.sh release $(ARMBIAN_PKG) $(DTB_HEADLESS) $(ALPINE_PKG)

alpine_clean:
	rm -f $(ARMBIAN_PKG) $(ALPINE_PKG)

else
alpine:
alpine_clean:
endif
