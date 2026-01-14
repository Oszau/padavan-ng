# https://thekelleys.org.uk

SRC_NAME = dnsmasq-2.92
SRC_URL  = https://thekelleys.org.uk/dnsmasq/$(SRC_NAME).tar.xz

CFLAGS += -DHAVE_BROKEN_RTC -DNO_INOTIFY -DNO_AUTH -DNO_LOOP -DNO_DUMPFILE -DNO_ID
CFLAGS += $(if $(CONFIG_IPV6),,-DNO_DHCP6)
CFLAGS += $(if $(CONFIG_USB_SUPPORT),,-DNO_TFTP)
CFLAGS += $(if $(CONFIG_FIRMWARE_INCLUDE_IPSET),,-DNO_IPSET)

CFLAGS += -ffunction-sections -fdata-sections -fvisibility=hidden
LDFLAGS += -Wl,--gc-sections

all: download_test extract_test
	$(MAKE) -C $(SRC_NAME)

download_test:
	( if [ ! -f $(SRC_NAME).tar.xz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.xz $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.xz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xJf $(SRC_NAME).tar.xz; \
		cat patches/*.patch | patch -d $(SRC_NAME) -r - -N -p1; \
	fi )

clean:
	$(MAKE) -C $(SRC_NAME) clean

romfs:
	$(ROMFSINST) $(SRC_NAME)/src/dnsmasq /usr/sbin/dnsmasq
