DTB_HEADLESS := dtbs/4.4-bsp/headless/rk3328-beikeyun.dtb
DTB_BOX := dtbs/4.4-bsp/box/rk3328-beikeyun.dtb

OUTPUT := output

all: armbian libreelec lakka

clean: armbian_clean libreelec_clean lakka_clean
	rm -f $(OUTPUT)/*.img $(OUTPUT)/*.xz

ifeq ($(BUILD_ARMBIAN),y)
ARMBIAN_URL_BASE := https://dl.armbian.com/rock64
ARMBIAN_PKGS := Ubuntu_bionic_default.7z Debian_stretch_default.7z

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

ifeq ($(BUILD_LIBREELEC),y)
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

ifeq ($(BUILD_LAKKA),y)
LAKKA_PKG := $(shell basename `hxwls "http://le.builds.lakka.tv/Rockchip.ROCK64.arm/?C=M&O=D" |grep 'img.gz$$' |head -1`)
LAKKA_IDB := loader/idbloader.bin

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
	./build-lakka.sh release $(LAKKA_PKG) $(DTB_BOX) $(LAKKA_IDB)

else
lakka:
lakka_clean:
endif
