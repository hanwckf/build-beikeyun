OUTPUT_DIR := output

DTB_HEADLESS := dtbs/4.4-bsp/headless/rk3328-beikeyun.dtb
DTB_BOX := dtbs/4.4-bsp/box/rk3328-beikeyun.dtb

ARMBIAN_URL_BASE := https://dl.armbian.com/rock64
ARMBIAN_PKGS := Ubuntu_bionic_default.7z Debian_stretch_default.7z

LIBREELEC_URL_BASE := http://archive.libreelec.tv
LIBREELEC_PKGS := 

.PRECIOUS: $(ARMBIAN_PKGS)

all: armbian

clean: armbian_clean

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
