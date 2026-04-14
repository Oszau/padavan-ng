# https://www.draisberghof.de/usb_modeswitch

SRC_NAME = usb-modeswitch-2.6.2
SRC_URL1 = https://www.draisberghof.de/usb_modeswitch/usb-modeswitch-2.6.2.tar.bz2

SRC_DATA = usb-modeswitch-data-20251207
SRC_URL2 = https://www.draisberghof.de/usb_modeswitch/usb-modeswitch-data-20251207.tar.bz2

CFLAGS  += -I$(STAGEDIR)/include/libusb-1.0
CFLAGS  += -Wall -ffunction-sections -fdata-sections -fvisibility=hidden
LDFLAGS += -Wl,--gc-sections -lusb-1.0

all: download_test extract_test
	make -j$(HOST_NCPU) -C $(SRC_NAME)

download_test:
	( if [ ! -f $(SRC_NAME).tar.bz2 ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.bz2 $(SRC_URL1) || rm -f $(SRC_NAME).tar.bz2; \
	fi )
	( if [ ! -f $(SRC_DATA).tar.bz2 ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_DATA).tar.bz2 $(SRC_URL2) || rm -f $(SRC_SATA).tar.bz2; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xjf $(SRC_NAME).tar.bz2; \
	fi )
	( if [ ! -d $(SRC_DATA) ]; then \
		tar xjf $(SRC_DATA).tar.bz2; \
	fi )

clean:
	if [ -f $(SRC_NAME)/Makefile ]; then \
		make -C $(SRC_NAME) distclean; \
	fi

romfs:
	$(ROMFSINST) -p +x $(SRC_NAME)/usb_modeswitch /bin/usb_modeswitch
	$(ROMFSINST) -d $(SRC_DATA)/usb_modeswitch.d /etc_ro/usb_modeswitch.d
