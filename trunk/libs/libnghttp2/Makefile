# https://github.com/nghttp2/nghttp2

SRC_VER = 1.68.0
SRC_NAME = nghttp2-$(SRC_VER)
SRC_URL = https://github.com/nghttp2/nghttp2/releases/download/v$(SRC_VER)/$(SRC_NAME).tar.xz

CFLAGS += -fPIC
CXXFLAGS += -fPIC

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)/build

download_test:
	( if [ ! -f $(SRC_NAME).tar.xz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.xz $(SRC_URL) \
		    || rm -f $(SRC_NAME).tar.xz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar --xz -xf $(SRC_NAME).tar.xz; \
		find "$(shell pwd)"/patches -type f -name '*.patch' -print0 \
		    | sort -z \
		    | xargs -r -t -0 -n 1 patch -d $(SRC_NAME) -p1 -i; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( mkdir -p $(SRC_NAME)/build && cd $(SRC_NAME)/build ; \
	cmake	-DCMAKE_INSTALL_PREFIX:PATH=/ \
		-DENABLE_LIB_ONLY=ON \
		-DBUILD_STATIC_LIBS=ON \
		-DBUILD_SHARED_LIBS=OFF \
		-DENABLE_STATIC_CRT=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOTDIR)/include/cross-mipsel-linux.cmake .. \
	)

clean:
	if [ -d $(SRC_NAME)/build ] ; then \
		rm -rf $(SRC_NAME)/build ; \
	fi ; \
	rm -f config_done

install:
	$(MAKE) -C $(SRC_NAME)/build install DESTDIR=$(STAGEDIR)

romfs:

