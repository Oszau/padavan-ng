SRC_NAME=strongswan-5.9.14
SRC_URL=https://download.strongswan.org/$(SRC_NAME).tar.bz2

CFLAGS += -ffunction-sections -fdata-sections
CFLAGS += $(if $(CONFIG_IPV6),-DCONFIG_IPV6,)
LDFLAGS += -Wl,--gc-sections,-L$(STAGEDIR)/lib,-rpath-link=../../src/libtls/.libs -lcrypto

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)
	$(MAKE) -C $(SRC_NAME) install DESTDIR=$(STAGEDIR)

download_test:
	( if [ ! -f $(SRC_NAME).tar.bz2 ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.bz2 $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.bz2; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xjf $(SRC_NAME).tar.bz2; \
		cat patches/*.patch | patch -d $(SRC_NAME) -r - -N -p1; \
	fi )

config_test:
	( if [ -f config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( cd $(SRC_NAME) ; \
	./configure \
		--with-sysroot=$(STAGEDIR) \
		--prefix=/usr \
		--sysconfdir=/etc/storage/strongswan \
		--disable-pki \
		--disable-fips-prf \
		--disable-botan \
		--disable-gmp \
		--disable-rc2 \
		--disable-cmac \
		--disable-xcbc \
		--disable-scepclient \
		--disable-vici \
		--disable-swanctl \
		--disable-dnskey \
		--disable-pgp \
		--disable-sshkey \
		--disable-constraints \
		--disable-revocation \
		--disable-random \
		--disable-des \
		--disable-aes \
		--disable-md5 \
		--disable-sha1 \
		--disable-sha2 \
		--disable-pkcs7 \
		--disable-pkcs12 \
		--disable-hmac \
		--enable-dhcp \
		--enable-farp \
		--enable-openssl \
		--enable-eap-dynamic \
		--enable-eap-identity \
		--enable-eap-tls \
		--enable-eap-mschapv2 \
		--enable-xauth-eap \
		--enable-xauth-noauth \
		--enable-systime-fix \
		--enable-monolithic \
		--with-resolv-conf=/etc/resolv.conf \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD) ; \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ] ; then \
		$(MAKE) -C $(SRC_NAME) clean ; \
	fi ;
	rm -f config_done

romfs:
	$(ROMFSINST) -x $(STAGEDIR)/usr/sbin/ipsec /usr/sbin/ipsec
	$(ROMFSINST) -d $(STAGEDIR)/usr/libexec/ipsec /usr/libexec/ipsec
	mkdir -p $(ROMFSDIR)/usr/lib/ipsec
	cp -fP $(STAGEDIR)/usr/lib/ipsec/*.so* $(ROMFSDIR)/usr/lib/ipsec
