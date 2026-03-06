# https://www.zerotier.com

SRC_VER = 1.16.0
SRC_NAME = ZeroTierOne-$(SRC_VER)
SRC_URL = https://github.com/zerotier/ZeroTierOne/archive/refs/tags/$(SRC_VER).tar.gz

CFLAGS += -ffunction-sections -fdata-sections -fvisibility=hidden
CFLAGS += $(if $(CONFIG_IPV6),-DCONFIG_IPV6,)
LDFLAGS += -Wl,--gc-sections

all: download_test extract_test
	$(MAKE) -C $(SRC_NAME) \
		ZT_EMBEDDED=1 \
		ZT_SSO_SUPPORTED=0 \
		ZT_NONFREE=0 \
		DEFS="" \
		OSTYPE="Linux"

download_test:
	( if [ ! -f $(SRC_NAME).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.gz $(SRC_URL) || rm -f $(SRC_NAME).tar.gz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xzf $(SRC_NAME).tar.gz; \
		cat patches/*.patch | patch -d $(SRC_NAME) -r - -N -p1; \
	fi )

clean:
	if [ -f $(SRC_NAME)/Makefile ] ; then \
		$(MAKE) -C $(SRC_NAME) distclean ; \
	fi ; \

romfs:
	$(ROMFSINST) $(SRC_NAME)/zerotier-one /usr/sbin/zerotier-one
	$(ROMFSINST) -s zerotier-one /usr/sbin/zerotier-cli
	$(ROMFSINST) -s zerotier-one /usr/sbin/zerotier-idtool
	$(ROMFSINST) -p +x /usr/bin/zerotier.sh
