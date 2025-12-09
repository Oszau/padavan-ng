# https://www.openssh.org
# https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/openssh/1:9.6p1-3ubuntu13.14/openssh_9.6p1-3ubuntu13.14.debian.tar.xz

SRC_NAME = openssh-9.6p1
SRC_URL = https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/$(SRC_NAME).tar.gz

CFLAGS += -ffunction-sections -fdata-sections
LDFLAGS += -Wl,--gc-sections

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)

download_test:
	( if [ ! -f $(SRC_NAME).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.gz $(SRC_URL) || rm -f $(SRC_NAME).tar.gz; \
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
	( cd $(SRC_NAME) ; \
	autoreconf ; \
	LD="$(CC)" \
	./configure \
		--prefix=/usr \
		--sysconfdir=/etc/storage/openssh \
		--libexecdir=/usr/libexec \
		--with-pid-dir=/var/run \
		--with-privsep-path=/var/empty \
		--with-privsep-user=sshd \
		--with-sandbox=no \
		--without-pam \
		--without-selinux \
		--without-bsd-auth \
		--without-kerberos5 \
		--disable-strip \
		--disable-etc-default-login \
		--disable-lastlog \
		--disable-utmp \
		--disable-utmpx \
		--disable-wtmp \
		--disable-wtmpx \
		--disable-libutil \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD) ; \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ] ; then \
		$(MAKE) -C $(SRC_NAME) distclean ; \
	fi ; \
	rm -f config_done

romfs:
ifeq ($(CONFIG_FIRMWARE_INCLUDE_OPENSSH),y)
	$(ROMFSINST) -d $(SRC_NAME)/moduli /etc_ro/ssh/moduli
	$(ROMFSINST) $(SRC_NAME)/libssh.so /lib/libssh.so
	$(ROMFSINST) $(SRC_NAME)/scp /usr/bin/scp
	$(ROMFSINST) $(SRC_NAME)/ssh /usr/bin/ssh
	$(ROMFSINST) $(SRC_NAME)/ssh-keygen /usr/bin/ssh-keygen
	$(ROMFSINST) $(SRC_NAME)/sshd /usr/sbin/sshd
	$(ROMFSINST) -p +x /usr/bin/sshd.sh
endif
	$(ROMFSINST) -d $(SRC_NAME)/sftp-server /usr/libexec/sftp-server
