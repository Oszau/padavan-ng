# https://www.7-zip.org

SRC_VER = 26.00
SRC_NAME = 7zip-$(SRC_VER)
SRC_URL = https://github.com/ip7z/7zip/archive/refs/tags/$(SRC_VER).tar.gz

all: download_test extract_test
	make -j$(HOST_NCPU) -C $(SRC_NAME)/CPP/7zip/Bundles/LzmaCon -f makefile.gcc
	cp $(SRC_NAME)/CPP/7zip/Bundles/LzmaCon/_o/lzma ./lzma

download_test:
	( if [ ! -f $(SRC_NAME).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.gz $(SRC_URL) || rm -f $(SRC_NAME).tar.gz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar zxf $(SRC_NAME).tar.gz; \
		find "$(shell pwd)"/patches -type f -name '*.patch' -print0 \
		  | sort -z \
		  | xargs -r -t -0 -n 1 patch -d $(SRC_NAME) -p1 -i; \
	fi )

clean:
	if [ -f $(SRC_NAME)/CPP/7zip/Bundles/LzmaCon/makefile.gcc ] ; then \
		make -C $(SRC_NAME)/CPP/7zip/Bundles/LzmaCon -f makefile.gcc clean; \
	fi ; \
	rm -f lzma
