SRC_NAME=mbedtls-3.6.6
SRC_URL=https://github.com/Mbed-TLS/mbedtls/releases/download/$(SRC_NAME)/$(SRC_NAME).tar.bz2

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)/build

download_test:
	( if [ ! -f $(SRC_NAME).tar.bz2 ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.bz2 $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.bz2; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar -xjf $(SRC_NAME).tar.bz2; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( mkdir -p $(SRC_NAME)/build && cd $(SRC_NAME)/build ; \
	cmake -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=/ \
		-DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
		-DUSE_STATIC_MBEDTLS_LIBRARY=ON \
		-DENABLE_TESTING=OFF \
		-DENABLE_PROGRAMS=OFF \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOTDIR)/include/cross-mipsel-linux.cmake .. \
	)

clean:
	rm -rf $(SRC_NAME)/build
	rm -f config_done

install:
	$(MAKE) -C $(SRC_NAME)/build install DESTDIR="$(STAGEDIR)"

romfs:
