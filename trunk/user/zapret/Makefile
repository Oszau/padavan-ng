
all:
ifneq (,$(filter y,$(CONFIG_FIRMWARE_INCLUDE_ZAPRET) $(CONFIG_FIRMWARE_INCLUDE_NFQWS)))
	$(MAKE) -C zapret all
endif
ifneq (,$(filter y,$(CONFIG_FIRMWARE_INCLUDE_ZAPRET2) $(CONFIG_FIRMWARE_INCLUDE_NFQWS2)))
	$(MAKE) -C zapret2 all
endif

clean:
	( for i in zapret zapret2; do \
		if [ -d $$i ]; then \
			$(MAKE) -C $$i clean; \
		fi; \
	done )

romfs:
	$(ROMFSINST) -p +x /usr/bin/zapret.sh
	$(ROMFSINST) -d config/zapret /usr/share/zapret
ifneq (,$(filter y,$(CONFIG_FIRMWARE_INCLUDE_ZAPRET) $(CONFIG_FIRMWARE_INCLUDE_NFQWS)))
	$(ROMFSINST) -d config/strategy /usr/share/zapret
	$(MAKE) -C zapret romfs
endif
ifneq (,$(filter y,$(CONFIG_FIRMWARE_INCLUDE_ZAPRET2) $(CONFIG_FIRMWARE_INCLUDE_NFQWS2)))
	$(ROMFSINST) -d config/strategy2 /usr/share/zapret
ifeq (,$(filter y,$(CONFIG_FIRMWARE_INCLUDE_ZAPRET) $(CONFIG_FIRMWARE_INCLUDE_NFQWS)))
	$(ROMFSINST) -d config/strategy2/strategy9 /usr/share/zapret/strategy
	$(ROMFSINST) -d config/strategy2/strategy5 /usr/share/zapret/strategy0
	$(ROMFSINST) -d config/strategy2/strategy6 /usr/share/zapret/strategy1
	$(ROMFSINST) -d config/strategy2/strategy7 /usr/share/zapret/strategy2
	$(ROMFSINST) -d config/strategy2/strategy8 /usr/share/zapret/strategy3
	$(ROMFSINST) -d config/strategy2/strategy9 /usr/share/zapret/strategy4
endif
	$(MAKE) -C zapret2 romfs
endif
