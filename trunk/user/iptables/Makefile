# https://www.netfilter.org

SRC_NAME = iptables-1.8.7
SRC_URL = https://www.netfilter.org/projects/iptables/files/$(SRC_NAME).tar.bz2

CFLAGS  += -ffunction-sections -fdata-sections -fvisibility=hidden
LDFLAGS += -Wl,--gc-sections

all: download_test extract_test config_test
	$(MAKE) -C $(SRC_NAME)
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
		cd $(SRC_NAME)/extensions && mkdir -p disabled; \
		for i in libebt_ libxt_set. libxt_SET. \
			libxt_policy. libipt_ah. libip6t_ah. libxt_esp. \
			libip6t_dst. libip6t_eui64. libip6t_frag. \
			libip6t_hbh. libip6t_hl. libip6t_ipv6header. \
			libip6t_mh. libip6t_rt. libip6t_srh. libipt_CLUSTERIP. \
			libipt_ECN. libipt_ULOG. libipt_realm. \
			libxt_AUDIT. libxt_CHECKSUM. libxt_CONNSECMARK. \
			libxt_CLASSIFY. libxt_HMARK. libxt_IDLETIMER. libxt_LED. \
			libxt_NFLOG. libxt_NFQUEUE. libxt_RATEEST. \
			libxt_SECMARK. libxt_SYNPROXY. libxt_TCPOPTSTRIP. libxt_TEE. \
			libxt_TPROXY. libxt_TRACE. libxt_addrtype. \
			libxt_cgroup. libxt_cluster. libxt_conntrack. \
			libxt_bpf. libxt_dccp. libxt_devgroup. libxt_comment. \
			libxt_ecn. libxt_hashlimit. libxt_helper. libxt_ipcomp. \
			libxt_ipvs. libxt_iprange. libxt_nfacct. libxt_osf. \
			libxt_owner. libxt_physdev. libxt_pkttype. \
			libxt_quota. libxt_rateest. libxt_rpfilter. \
			libxt_sctp. libxt_socket. libxt_statistic. libxt_string. \
			libip6t_NETMAP. libip6t_MASQUERADE. libip6t_DNAT. \
			libip6t_SNPT. libip6t_SNAT. libip6t_DNPT. libip6t_REDIRECT. \
		; do mv $$i* disabled; done; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

define set_ext
	$(if $($1), \
		$(foreach ext,$2, \
			cp -f $(SRC_NAME)/extensions/disabled/$(ext)* $(SRC_NAME)/extensions; \
		), \
		$(foreach ext,$2, \
			rm -f $(SRC_NAME)/extensions/$(ext)*; \
		) \
	)
endef

configure:
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_DCCP,libxt_dccp.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_ADDRTYPE,libxt_addrtype.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_COMMENT,libxt_comment.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_OWNER,libxt_owner.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_IPRANGE,libxt_iprange.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_CONNTRACK,libxt_conntrack.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_PHYSDEV,libxt_physdev.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_STRING,libxt_string.)
	$(call set_ext,CONFIG_NETFILTER_XT_TARGET_NFQUEUE,libxt_NFQUEUE.)
	$(call set_ext,CONFIG_NETFILTER_XT_TARGET_TPROXY,libxt_TPROXY.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_POLICY,libxt_policy.)
	$(call set_ext,CONFIG_NETFILTER_XT_MATCH_ESP,libxt_esp.)
	$(call set_ext,CONFIG_IP_NF_MATCH_AH,libipt_ah.)
	$(call set_ext,CONFIG_IP6_NF_MATCH_AH,libip6t_ah.)
	$(call set_ext,CONFIG_NETFILTER_XT_TARGET_CLASSIFY,libxt_CLASSIFY.)
	$(call set_ext,CONFIG_NETFILTER_XT_TARGET_IMQ,libxt_IMQ.)
	$(call set_ext,CONFIG_FIRMWARE_INCLUDE_IPSET,libxt_set. libxt_SET.)
	( cd $(SRC_NAME); \
	./configure \
		--prefix= \
		--enable-static \
		--disable-shared \
		--disable-nftables \
		--disable-connlabel \
		--with-xt-lock-name=/var/lock/xtables.lock \
		--with-xtlibdir=/usr/lib/xtables \
		--with-kernel=$(ROOTDIR)/$(LINUXDIR) \
		$(if $(CONFIG_IPV6),--enable-ipv6,--disable-ipv6) \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD); \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ]; then \
		$(MAKE) -C $(SRC_NAME) distclean; \
	fi; \
	rm -f config_done

romfs:
	$(ROMFSINST) $(SRC_NAME)/iptables/xtables-legacy-multi /bin/xtables-legacy-multi
	$(ROMFSINST) -s xtables-legacy-multi /bin/iptables
	$(ROMFSINST) -s xtables-legacy-multi /bin/iptables-restore
	$(ROMFSINST) -s xtables-legacy-multi /bin/iptables-save
ifdef CONFIG_IPV6
	$(ROMFSINST) -s xtables-legacy-multi /bin/ip6tables
	$(ROMFSINST) -s xtables-legacy-multi /bin/ip6tables-restore
	$(ROMFSINST) -s xtables-legacy-multi /bin/ip6tables-save
endif
