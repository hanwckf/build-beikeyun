OUTPUT_DIR := output

DTB_HEADLESS := dtbs/4.4-bsp/headless/rk3328-beikeyun.dtb
DTB_BOX := dtbs/4.4-bsp/box/rk3328-beikeyun.dtb

ARMBIAN_URL_BASE := https://dl.armbian.com/rock64
ARMBIAN_PKGS := Ubuntu_bionic_default.7z Debian_stretch_default.7z

all: armbian libreelec

clean: armbian_clean libreelec_clean

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

ifeq ($(BUILD_LIBREELEC),y)
LIBREELEC_PKG := $(shell basename `hxwls "http://archive.libreelec.tv/?C=M;O=D" |grep rock64.img.gz |head -1`)
libreelec: libreelec_dl libreelec_release
libreelec_clean:
	rm -f $(LIBREELEC_PKG)
else
LIBREELEC_PKG :=
libreelec:
libreelec_clean:
endif

libreelec_dl:
	( if [ -n $(LIBREELEC_PKG) ]; then \
		if [ ! -f $(LIBREELEC_PKG) ]; then \
			wget "http://archive.libreelec.tv/$(LIBREELEC_PKG)" ; \
		fi \
	else \
		echo "fetch libreelec dl url fail" ; exit 1 ; \
	fi )

libreelec_release: libreelec_dl
	./build-libreelec.sh release $(LIBREELEC_PKG) $(DTB_BOX)
