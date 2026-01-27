# https://curl.se

SRC_NAME = curl-8.18.0
SRC_URL = https://github.com/curl/curl/releases/download/curl-8_18_0/$(SRC_NAME).tar.xz

ifneq (,$(filter y,$(QUIC_ENABLED) $(CONFIG_FIRMWARE_INCLUDE_OPENSSL_35)))
SSL_VER = 3.5
else ifeq ($(CONFIG_FIRMWARE_INCLUDE_OPENSSL_11),y)
SSL_VER = 1.1
else ifeq ($(CONFIG_FIRMWARE_INCLUDE_OPENSSL_10),y)
SSL_VER = 1.0
else
SSL_VER = 3.0
endif

ifeq ($(shell LC_ALL=C [ $(SSL_VER) '<' 3.0 ] && echo 1), 1)
SRC_NAME = curl-8.17.0
SRC_URL = https://github.com/curl/curl/releases/download/curl-8_17_0/$(SRC_NAME).tar.xz
endif

QUIC = --without-nghttp3 --without-ngtcp2 --without-openssl-quic
ifeq ($(CONFIG_FIRMWARE_INCLUDE_QUIC),y)
QUIC = --with-nghttp3 --without-ngtcp2 --with-openssl-quic
endif
ifeq ($(CONFIG_FIRMWARE_INCLUDE_QUIC_NGTCP2),y)
QUIC = --with-nghttp3 --with-ngtcp2 --without-openssl-quic
endif

CPPFLAGS += $(CFLAGS)

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)

download_test:
	( if [ ! -f $(SRC_NAME).tar.xz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.xz $(SRC_URL) || rm -f $(SRC_NAME).tar.xz; \
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
	( cd $(SRC_NAME) ; \
	autoreconf -fi ; \
	./configure \
		--prefix= \
		--disable-static \
		--enable-openssl-auto-load-config \
		--enable-shared \
		$(if $(CONFIG_IPV6),--enable-ipv6,--disable-ipv6) \
		$(QUIC) \
		--without-quiche \
		--disable-ipfs \
		--disable-rtsp \
		--disable-websockets \
		--disable-gopher \
		--disable-ldap \
		--disable-ldaps \
		--disable-rt \
		--disable-rtsp \
		--disable-telnet \
		--disable-tftp \
		--disable-smb \
		--disable-smtp \
		--disable-pop3 \
		--disable-imap \
		--disable-sspi \
		--disable-dict \
		--disable-ares \
		--disable-debug \
		--disable-curldebug \
		--disable-manual \
		--disable-verbose \
		--disable-tls-srp \
		--disable-libcurl-option \
		--disable-threaded-resolver \
		--disable-mqtt \
		--disable-alt-svc \
		--disable-hsts \
		--disable-ntlm \
		--disable-docs \
		--without-brotli \
		--without-gnutls \
		--without-ca-path \
		--without-ca-fallback \
		--without-default-ssl-backend \
		--without-libidn2 \
		--without-libpsl \
		--without-librtmp \
		--without-libssh \
		--without-libssh2 \
		--with-nghttp2 \
		--without-mbedtls \
		--without-schannel \
		--without-wolfssl \
		--without-winidn \
		--without-zsh-functions-dir \
		--with-zlib=$(STAGEDIR) \
		--with-ssl=$(STAGEDIR) \
		--with-ca-bundle=/etc/ssl/cert.pem \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD) ; \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ] ; then \
		$(MAKE) -C $(SRC_NAME) distclean ; \
	fi ; \
	rm -f config_done

install:
	$(MAKE) -C $(SRC_NAME) install DESTDIR=$(STAGEDIR)

romfs:
ifeq ($(CONFIG_FIRMWARE_INCLUDE_CURL),y)
	$(ROMFSINST) -d $(DESTDIR)/bin/curl /usr/bin/curl
endif
	cp -fP $(DESTDIR)/lib/libcurl.so* $(ROMFSDIR)/lib
