# https://downloads.uclibc-ng.org/releases

SRC_VER = 1.0.58
SRC_NAME = uClibc-ng-$(SRC_VER)
SRC_URL = https://downloads.uclibc-ng.org/releases/$(SRC_VER)/$(SRC_NAME).tar.xz

.EXPORT_ALL_VARIABLES:
.PHONY: all romfs clean

ifndef ROOTDIR
ROOTDIR=..
endif
ifndef ROMFSDIR
ROMFSDIR=$(ROOTDIR)/romfs
endif

include $(PROJECT_CONFIG)
include $(ARCH_CONFIG)
include $(LINUX_CONFIG)
include $(ROOTDIR)/include/configedit.mk

DESTDIR=$(ROOTDIR)/stage

all: download_test extract_test
	cp -fL $(ROOTDIR)/configs/boards/uclibc-mipsel.config $(SRC_NAME)/.config
ifeq ($(CONFIG_IPV6),y)
	$(call KconfigEnableOption,UCLIBC_HAS_IPV6,$(SRC_NAME)/.config)
else
	$(call KconfigDisableOption,UCLIBC_HAS_IPV6,$(SRC_NAME)/.config)
endif
ifneq (,$(filter y,$(CONFIG_MMC_BLOCK) $(CONFIG_BLK_DEV_SD)))
	$(call KconfigEnableOption,UCLIBC_HAS_LIBICONV,$(SRC_NAME)/.config)
else
	$(call KconfigDisableOption,UCLIBC_HAS_LIBICONV,$(SRC_NAME)/.config)
endif
	$(call KconfigSetOption,UCLIBC_EXTRA_CFLAGS,"$(CPUFLAGS) $(CFLAGS)",$(SRC_NAME)/.config)
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME) oldconfig || exit $$? ; \
	if [ ! -f $(DESTDIR)/.installed_$(SRC_NAME) ] ; then \
		$(MAKE) -C $(SRC_NAME) PREFIX=$(DESTDIR) DEVEL_PREFIX=/ MULTILIB_DIR=lib install_runtime install_utils && \
		touch $(DESTDIR)/.installed_$(SRC_NAME) ; \
	fi

download_test:
	( if [ ! -f $(SRC_NAME).tar.xz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.xz $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.xz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar --xz -xf $(SRC_NAME).tar.xz; \
	fi )

print-%:
	@echo $($*)

%_only:
	$(MAKE) -C $(@:_only=)

%_romfs:
	$(MAKE) -C $(@:_romfs=) romfs

%_clean:
	$(MAKE) -C $(@:_clean=) clean

romfs:
	$(STRIP) $(DESTDIR)/bin/ldd ; \
	$(STRIP) $(DESTDIR)/sbin/ldconfig ; \
	cp -fP $(DESTDIR)/bin/ldd $(ROMFSDIR)/bin ; \
	cp -fP $(DESTDIR)/lib/libuClibc*.so* $(ROMFSDIR)/lib ; \
	cp -fP $(DESTDIR)/lib/libc.so.0 $(ROMFSDIR)/lib ; \
	cp -fP $(DESTDIR)/lib/ld-uClibc*.so* $(ROMFSDIR)/lib ; \
	chmod +x $(ROMFSDIR)/lib/libuClibc*.so

clean:
	rm -f $(DESTDIR)/.installed_$(SRC_NAME)
	$(MAKE) -C $(SRC_NAME) distclean
