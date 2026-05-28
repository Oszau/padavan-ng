# https://libusb.info
# https://github.com/libusb/libusb

SRC_VER = 1.0.30
SRC_NAME = libusb-$(SRC_VER)
SRC_URL = https://github.com/libusb/libusb/releases/download/v$(SRC_VER)/libusb-$(SRC_VER).tar.bz2

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)

download_test:
	( if [ ! -f $(SRC_NAME).tar.bz2 ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.bz2 $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.bz2; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xjf $(SRC_NAME).tar.bz2; \
		cat patches/*.patch | patch -d $(SRC_NAME) -r - -N -p1; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( cd $(SRC_NAME); \
	autoreconf; \
	ac_cv_lib_rt_clock_gettime=no \
	./configure \
		--prefix= \
		--disable-static \
		--disable-log \
		--disable-udev \
		--disable-examples-build \
		--disable-tests-build \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD); \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ]; then \
		$(MAKE) -C $(SRC_NAME) distclean; \
	fi; \
	rm -f config_done

install:
	$(MAKE) -C $(SRC_NAME) install DESTDIR=$(STAGEDIR)

romfs:
	cp -fP $(DESTDIR)/lib/libusb-1.0.so* $(ROMFSDIR)/lib
	cp -fP $(CONFIG_CROSS_COMPILER_ROOT)/mipsel-linux-uclibc/sysroot/lib/libatomic.so* $(ROMFSDIR)/lib
