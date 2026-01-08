# http://miniupnp.free.fr

SRC_NAME = miniupnpd-2.3.9
SRC_URL = http://miniupnp.free.fr/files/$(SRC_NAME).tar.gz

all: download_test extract_test config_test
	$(MAKE) -C $(SRC_NAME)

download_test:
	( if [ ! -f $(SRC_NAME).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.gz $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.gz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xf $(SRC_NAME).tar.gz; \
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
	./configure \
		--firewall=iptables \
		--vendorcfg \
		--portinuse \
		--leasefile \
		--disable-pppconn \
		--disable-tests \
#		$(if $(CONFIG_IPV6),--ipv6) \
#		--igd2 \
	)

clean:
	( if [ -d $(SRC_NAME) ]; then \
		$(MAKE) -C $(SRC_NAME) clean; \
	fi )
	rm -f config_done

romfs:
	$(ROMFSINST) $(SRC_NAME)/miniupnpd /usr/bin/miniupnpd
