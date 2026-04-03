# https://openssl-library.org/source
# https://www.ccadb.org/resources
# https://wiki.mozilla.org/CA/Included_Certificates

all:
	$(MAKE) -C $(SSL_VER) all

%:
	$(MAKE) -C $(SSL_VER) $@

clean:
	( for i in `ls -d */`; do \
		if [ -d $$i ]; then \
			$(MAKE) -C $$i clean; \
		fi; \
	done )

romfs:
	$(MAKE) -C $(SSL_VER) romfs
	$(ROMFSINST) /etc_ro/ca-certificates.crt
