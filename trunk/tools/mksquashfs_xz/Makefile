# https://github.com/plougher/squashfs-tools
# https://github.com/tukaani-project/xz

SRC_NAME1=squashfs-4.7.5
SRC_URL1=https://github.com/plougher/squashfs-tools/archive/refs/tags/4.7.5.tar.gz

SRC_NAME2=xz-5.8.2
SRC_URL2=https://github.com/tukaani-project/xz/archive/refs/tags/v5.8.2.tar.gz

all: download_test extract_test config_xz build_xz build_squashfs

download_test:
	( if [ ! -f $(SRC_NAME1).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME1).tar.gz $(SRC_URL1) || rm -f $(SRC_NAME1).tar.gz; \
	fi )
	( if [ ! -f $(SRC_NAME2).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME2).tar.gz $(SRC_URL2) || rm -f $(SRC_NAME2).tar.gz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME1) ]; then \
		tar xzf $(SRC_NAME1).tar.gz --wildcards --strip-components 1 --overwrite "*/squashfs-tools"; \
		mv squashfs-tools $(SRC_NAME1); \
		cat patches_squashfs/*.patch | patch -d $(SRC_NAME1) -r - -N -p1; \
	fi )
	( if [ ! -d $(SRC_NAME2) ]; then \
		tar zxf $(SRC_NAME2).tar.gz; \
	fi )

config_xz:
	( if [ -f ./config_xz_done ]; then \
		echo "the same configuration"; \
	else \
		make configure_xz && touch config_xz_done; \
	fi )

configure_xz:
	( cd $(SRC_NAME2) ; \
	./autogen.sh ; \
	./configure \
		--disable-shared \
		--disable-werror \
		--disable-xz \
		--disable-xzdec \
		--disable-lzmadec \
		--disable-lzmainfo \
		CFLAGS="-std=c99" ; \
	)

build_xz:
	make -j$(HOST_NCPU) -C $(SRC_NAME2)

build_squashfs:
	make -j$(HOST_NCPU) -C $(SRC_NAME1) XZUTILSDIR=$(shell pwd)/$(SRC_NAME2) ; \
	cp $(SRC_NAME1)/mksquashfs ./

clean:
	if [ -f $(SRC_NAME2)/Makefile ] ; then \
		make -C $(SRC_NAME2) distclean ; \
	fi
	if [ -f $(SRC_NAME1)/Makefile ] ; then \
		make -C $(SRC_NAME1) clean ; \
	fi
	rm -f config_xz_done
	rm -f mksquashfs
