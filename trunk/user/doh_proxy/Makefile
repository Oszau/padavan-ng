# https://github.com/aarond10

SRC_VER = 8018812
SRC_NAME = https_dns_proxy-$(SRC_VER)
SRC_URL = https://github.com/aarond10/https_dns_proxy/archive/refs/heads/master.tar.gz

CFLAGS  += -Os -ffunction-sections -fdata-sections -fvisibility=hidden -fPIC
LDFLAGS += -Wl,--gc-sections,-rpath-link,$(STAGEDIR)/lib -lcurl -lssl -lcrypto -lz

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)/build

download_test:
	( if [ ! -f $(SRC_NAME).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.gz $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.gz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		mkdir -p $(SRC_NAME) && tar -zx --strip-components=1 -f $(SRC_NAME).tar.gz -C $(SRC_NAME); \
		cat patches/*.patch | patch -d $(SRC_NAME) -r - -N -p1; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( mkdir -p $(SRC_NAME)/build && cd $(SRC_NAME)/build ; \
	cmake   -DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_BUILD_TYPE=Release \
		-DGIT_EXECUTABLE= \
		-DSW_VERSION=git-$(SRC_VER) \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOTDIR)/include/cross-mipsel-linux.cmake .. \
	)

clean:
	rm -rf $(SRC_NAME)/build
	rm -f config_done

romfs:
	$(ROMFSINST) $(SRC_NAME)/build/https_dns_proxy /usr/sbin/https_dns_proxy
	$(ROMFSINST) -p +x /usr/bin/doh_proxy.sh
	$(ROMFSINST) -d /www/doh.json
