# https://github.com/shadowsocks/shadowsocks-libev
# with support pcre, not pcre2 (except 7bb250739ef0067c62e4ffd533ec8cee2775995a)
# git clone https://github.com/shadowsocks/shadowsocks-libev
# git submodule update --init --recursive
# git checkout b2a0c545d8ce2d35ba3f4a77fe710861b1b74628

SRC_NAME = shadowsocks-libev-3.3.6

CFLAGS  += -ffunction-sections -fdata-sections -fvisibility=hidden
CFLAGS  += $(if $(CONFIG_IPV6),-DCONFIG_IPV6,)
LDFLAGS += -Wl,--gc-sections

all: extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xf $(SRC_NAME).tar.gz ; \
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
	autoreconf -fi; \
	./configure \
		--prefix=/usr \
		--disable-documentation \
		--disable-ssp \
		--disable-assert \
		--with-pcre="$(STAGEDIR)/lib" \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD); \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ]; then \
		$(MAKE) -C $(SRC_NAME) distclean; \
	fi ; \
	rm -f config_done

romfs:
ifeq ($(CONFIG_FIRMWARE_INCLUDE_SSREDIR),y)
	$(ROMFSINST) $(SRC_NAME)/src/ss-redir /usr/bin/ss-redir
endif
ifeq ($(CONFIG_FIRMWARE_INCLUDE_SSLOCAL),y)
	$(ROMFSINST) $(SRC_NAME)/src/ss-local /usr/bin/ss-local
endif
