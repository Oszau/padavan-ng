#!/bin/sh

###

MODULE="wireguard"
[ -d "/lib/modules/3.4.113/kernel/net/amneziawg" ] \
    && MODULE="amneziawg"

WG="wg"
IF_NAME="wg0"
IF_ADDR="$(nvram get vpnc_wg_if_addr | tr -s ' ,' '\n')"
IF_MTU="$(nvram get vpnc_wg_mtu)"
[ "$IF_MTU" ] || IF_MTU=1420
IF_PRIVATE="$(nvram get vpnc_wg_if_private)"
IF_PRESHARED="$(nvram get vpnc_wg_if_preshared)"
IF_DNS="$(nvram get vpnc_wg_if_dns | tr -s ',' ' ')"

unset DEFAULT
[ "$(nvram get vpnc_dgw)" = "1" ] && DEFAULT=1

PID_WATCHDOG="/var/run/wg_watchdog.pid"

PEER_PUBLIC="$(nvram get vpnc_wg_peer_public)"
PEER_PORT="$(nvram get vpnc_wg_peer_port)"
PEER_ENDPOINT="$(nvram get vpnc_wg_peer_endpoint)${PEER_PORT:+":$PEER_PORT"}"
PEER_KEEPALIVE="$(nvram get vpnc_wg_peer_keepalive)"
[ -n "$PEER_KEEPALIVE" ] || PEER_KEEPALIVE=25
PEER_ALLOWEDIPS="$(nvram get vpnc_wg_peer_allowedips | tr -d ' ')"
POST_SCRIPT="/etc/storage/vpnc_post_script.sh"

REMOTE_NETWORK_LIST="/etc/storage/vpnc_remote_network.list"
EXCLUDE_NETWORK_LIST="/etc/storage/vpnc_exclude_network.list"

NV_CLIENTS_LIST="$(nvram get vpnc_clients_allowed | tr -s ' ,' '\n')"
NV_IPSET_LIST="$(nvram get vpnc_ipset_allowed | tr -s ' ,' '\n')"

TABLE=51
FWMARK=51820
PREF_WG=5182
PREF_MAIN=5181

DNSMASQ_IPSET="unblock"

# nethash remote networks
VPN_REMOTE_IPSET="vpn.remote"
# nethash excluded remote networks
VPN_EXCLUDE_IPSET="vpn.exclude"
# nethash allowed LAN clients
VPN_CLIENTS_IPSET="vpn.clients"

###

unset IPSET
[ -x "/sbin/ipset" ] && IPSET=1

log()
{
    [ -n "$*" ] || return
    echo "$@"
    logger -t $MODULE "$@"
}

error()
{
    log "error: $@" >&2
    stop_wg
    exit 1
}

die()
{
    [ -n "$*" ] && echo "$@" >&2
    exit 1
}

is_started()
{
    [ -d "/sys/class/net/${IF_NAME}" ]
}

prepare_wg()
{
    modprobe -q $MODULE

    sysctl -q net.ipv4.conf.all.src_valid_mark=1
    sysctl -q net.ipv6.conf.all.disable_ipv6=0 2>/dev/null
    sysctl -q net.ipv6.conf.all.forwarding=1 2>/dev/null
}

wg_setdns()
{
    [ "$IF_DNS" ] || return

    nvram set vpnc_dns_t="$IF_DNS"
    update_resolvconf
}

setconf_wg()
{
    is_started || return 1

    if ! ip addr show $IF_NAME | grep -q "inet6"; then
        PEER_ALLOWEDIPS=$(echo "$PEER_ALLOWEDIPS" | tr -s ',' '\n' | grep -v ':' | tr -s '\n' ',' | sed 's/,$//')
    fi

    local awg
    [ "$MODULE" = "amneziawg" ] && awg="
S1 = 0
S2 = 0
Jc = 4
Jmin = 33
Jmax = 66
H1 = 1
H2 = 2
H3 = 3
H4 = 4
# quic vk.com
I1 = <b 0xc3000000010870ac9c05f49d2bff0341d26000421578ace2b50e80d3a3e8b2c2e2e5f50aebf6f7364c9fbed6be8c14606445db7e5c0f75b825ffc3d872b3c463422f0c6334b45a1d1297ee2abda6150110864de45ade52b8a2e33a7c4db399678ccb0501ce14696ae1de40c350293d31db073976e3eae493500358df59b6e16867d4c39ff670168bf0ab50e43aa0fc0814c0762227ff93f334522d9562142dcdef7241b554bfe2c27a3ab066d516f4d31a47526318c644e15d90e98899e25c0ce8a67e14df149769c3d14833d27a25e25fde8afd68f587cc573e8c88e502793b50626f4c5267a5786b2903172a0ef4eea2fa282a02e3d3385d598baa9cacb9395d6c43c5ccbbdce9845a39ded847779f00c44cf5df34f3ad2a22e63504316b748eabacb3b03a1cc3df9c8d6ab60a0255b7f8d433d6d0a671b5cf30a0af2c04a7138cc1b264382e164ebbbcc290176ac9d6672e57cac55effa9df991a0ec1b4ed63910432ff03b187c3a22206c6a4914e16d59e36f011a08f03f3ac7baed06a884f9fa3ee84ab2d097d4863f84edc87b624ca9aeafcec920339d3addc7b5fae21e59cc47c58147b244300ad857e71b8cb9772c4fed8a7a775744f0d8448c70a491e3a7fa5a98c0997be9319a32495011cafb4c2f9b3ade1ef1a5efbc00dd7374e5ea0226d62934a2847c55c0d524337d4073557e96b9ff177414ef03945503fb7c6149db4c3f4a449e70363fe259360de0df0d194f43a44dd364acadb6683262927e1b3dbcbb8e8a610ab>
"

    cat > "/tmp/${IF_NAME}.conf.$$" <<EOF
[Interface]
PrivateKey = $IF_PRIVATE
FwMark = $FWMARK
$awg

[Peer]
PublicKey = $PEER_PUBLIC
Endpoint = $PEER_ENDPOINT
PersistentKeepalive = $PEER_KEEPALIVE
AllowedIPs = $PEER_ALLOWEDIPS
EOF
    [ "$IF_PRESHARED" ] && echo "PresharedKey = $IF_PRESHARED" >> "/tmp/${IF_NAME}.conf.$$"

    echo "precedence ::ffff:0:0/96  100" > /etc/gai.conf
    local res=$($WG setconf $IF_NAME "/tmp/${IF_NAME}.conf.$$" 2>&1)
    rm -f /etc/gai.conf
    rm -f "/tmp/${IF_NAME}.conf.$$"

    [ "$1" = "reconnect" ] && return

    if ! echo $res | grep -q "error"; then
        log "configuration $IF_NAME applied successfully"
        $WG show $IF_NAME | grep -A 5 "peer:" | while read i; do
            log "$i"
        done
    else
        echo "$res" | while read i; do
            log "$i"
        done

        stop_wg
        return 1
    fi
}

prevent_access_loss()
{
    local i ep

    for i in \
        $(nvram get lan_ipaddr) \
        $(nvram get wan_ipaddr) \
        $(nvram get wan0_ipaddr)
    do
        [ "$i" = "0.0.0.0" ] && continue
        ip rule add from $i table main pref $PREF_MAIN
    done

    ep=$($WG show $IF_NAME endpoints | sed -r 's/^.+\t//; s/:[0-9]+$//; s/[][]*//g')
    [ -n "$ep" ] || return

    if [ "$ep" = "${ep#*:}" ]; then
        ip rule add to "$ep" table main pref $PREF_MAIN
    else
        ip -6 rule add to "$ep" table main pref $PREF_MAIN
    fi
}

add_default_route()
{
    ip rule add fwmark $FWMARK table $TABLE pref $PREF_WG
    ip route replace default dev $IF_NAME table $TABLE 2>/dev/null \
        && log "add default route dev $IF_NAME table $TABLE" \
        || error "unable to add default route dev $IF_NAME table $TABLE"
}

add_route()
{
    # ¯\_(ツ)_/¯
    sync && sysctl -q vm.drop_caches=3
    usleep 100000

    add_default_route

    # for local cloudflare warp support on the router
    # padavan does not support nat64

    ip addr show $IF_NAME | grep -q "inet6" \
        && ip -6 route replace default dev $IF_NAME metric 1024 2>/dev/null

    prevent_access_loss
}

wg_if_init()
{
    local i p

    prepare_wg

    ip link add dev $IF_NAME type $MODULE 2>/dev/null || error "cannot create $IF_NAME"
    ip link set dev $IF_NAME mtu $IF_MTU

    for i in $IF_ADDR; do
        p=4; [ "$i" != "${i#*:}" ] && p=6
        ip -$p addr add "$i" dev $IF_NAME 2>/dev/null || log "warning: cannot set $IF_NAME address $i"
    done

    local if_ip=$(ip addr show dev $IF_NAME | awk '/inet/{print $2}')
    [ "$if_ip" ] || error "$IF_NAME interface address not set"

    setconf_wg || die

    if ip link set $IF_NAME up; then
        log "client started, interface: $IF_NAME, addresses: "$if_ip
    else
        error "$IF_NAME startup failed"
    fi

    send_ping
}

reconnect_wg()
{
    # reconnect using current config

    if ! check_connected; then
        [ "$1" ] || log "trying connect to $PEER_ENDPOINT"
        setconf_wg reconnect
        check_connection_status
        if [ $? -eq 0 ]; then
            log "successfully connected"
            return 0
        else
            return 1
        fi
    fi
}

get_latest_handshakes()
{
    $WG show $IF_NAME latest-handshakes | cut -f2
}

send_ping()
{
    timeout 1 ping -I $IF_NAME 255.255.255.255 >/dev/null 2>&1 &
}

check_connected()
{
    local lh now

    is_started || die

    lh=$(get_latest_handshakes)
    [ "$lh" ] || error "no peer in config"
    [ "$lh" -eq 0 ] && return 1

    now=$(date +%s)
    if [ "$((now - lh))" -gt "300" ]; then
        log "latest handshake was more than 5 minutes ago"
        return 1
    elif [ "$((now - lh))" -gt "$PEER_KEEPALIVE" ]; then
        send_ping
    fi

    return 0
}

check_connection_status()
{
    local loop=0
    while is_started; do
        [ "$loop" -ge 10 ] && break
        check_connected && return 0
        loop=$((loop + 1))
        sleep 1
    done

    return 1
}

start_wg()
{
    is_started && die "already started"

    ipset_create
    start_watchdog &
    echo $! > "$PID_WATCHDOG"
}

start_watchdog()
{
    local pid="$(cat "$PID_WATCHDOG" 2>/dev/null)"
    local no_log

    # waiting restart zapret firewall rules
    sleep 2

    wg_if_init
    add_route
    wg_setdns
    start_fw

    if check_connection_status; then
        log "successfully connected"
    else
        log "connection may be blocked: $PEER_ENDPOINT"
    fi

    while is_started; do
        [ "$pid" = "$(cat $PID_WATCHDOG 2>/dev/null)" ] || die
        if reconnect_wg $no_log; then
            no_log=
        else
            # disable spam to log
            no_log=1
        fi
        sleep 10
    done

    stop_fw
}

reload_wg()
{
    is_started || return 1

    ipset_create
    stop_fw
    start_fw && log "access control rules successfully updated"
}

update_wg()
{
    is_started || return 1

    start_fw
}

stop_wg()
{
    stop_fw

    ip route flush table $TABLE 2>/dev/null
    ip -6 route del default dev $IF_NAME 2>/dev/null

    while ip rule del pref $PREF_WG 2>/dev/null; do true; done
    while ip rule del pref $PREF_MAIN 2>/dev/null; do true; done
    while ip -6 rule del pref $PREF_MAIN 2>/dev/null; do true; done

    ip link set $IF_NAME down 2>/dev/null
    ip link del dev $IF_NAME 2>/dev/null \
        && log "client stopped"
}

filter_ipv4()
{
    grep -E -x '^[[:space:]]*((25[0-5]|2[0-4][0-9]|1[0-9]{2}|0?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|0?[0-9]{1,2})(/(3[0-2]|[12]?[0-9]))?[[:space:]]*$' \
        | sed -E 's#/32|/0##g' | sort | uniq
}

ipset_load()
{
    # $1: "list" - file list; "" - var with line break

    local mode="$1"
    local name="$2"
    local list="$3"

    [ -n "$name" ] || return
    ipset -q -N $name nethash \
        && log "ipset '$name' created successfully"
    ipset flush $name

    if [ "$mode" = "list" ]; then
        [ -s "$list" ] || return
        filter_ipv4 < $list \
            | sed -E 's#^(.*)$#add '"$name"' \1#' \
            | ipset restore
    else
        [ -n "$list" ] || return
        printf '%s\n' "$list" | filter_ipv4 \
            | sed -E 's#^(.*)$#add '"$name"' \1#' \
            | ipset restore
    fi

    [ $? -eq 0 ] || log "ipset '$name' failed to update"
}

ipset_create()
{
    # create ipset ipv4 entrys

    [ -n "$IPSET" ] || return

    ipset -q -N $DNSMASQ_IPSET nethash timeout 21600 \
        && log "ipset '$DNSMASQ_IPSET' with timeout 21600 created successfully"

    ipset_load "list" "$VPN_REMOTE_IPSET" "$REMOTE_NETWORK_LIST"
    ipset_load "list" "$VPN_EXCLUDE_IPSET" "$EXCLUDE_NETWORK_LIST"
    ipset_load "nv" "$VPN_CLIENTS_IPSET" "$NV_CLIENTS_LIST"

    local name
    for name in $NV_IPSET_LIST; do
        ipset -q -N $name nethash \
            && log "ipset '$name' created successfully"
    done
}

ipt_set_rules()
{
    local i

    if [ -n "$IPSET" ]; then
        if [ -n "$NV_CLIENTS_LIST" ]; then
            echo "-A vpnc_wireguard -m set ! --match-set $VPN_CLIENTS_IPSET src -j RETURN"
        fi

        echo "-A vpnc_wireguard -m set --match-set $VPN_EXCLUDE_IPSET dst -j RETURN"

        if [ -n "$DEFAULT" ]; then
            echo "-A vpnc_wireguard -j vpnc_wireguard_mark"
        else
            for i in "$VPN_REMOTE_IPSET" $NV_IPSET_LIST; do
                [ -n "$i" ] && echo "-A vpnc_wireguard -m set --match-set $i dst -j vpnc_wireguard_mark"
            done
        fi
    else
        for i in $(filter_ipv4 < "$EXCLUDE_NETWORK_LIST"); do
            echo "-A vpnc_wireguard -d $i -j RETURN"
        done

        if [ -n "$NV_CLIENTS_LIST" ]; then
            for i in $NV_CLIENTS_LIST; do
                echo "-A vpnc_wireguard -s $i -j vpnc_wireguard_remote"
            done
        else
            echo "-A vpnc_wireguard -j vpnc_wireguard_remote"
        fi

        if [ -n "$DEFAULT" ]; then
            echo "-A vpnc_wireguard_remote -j vpnc_wireguard_mark"
        else
            for i in $(filter_ipv4 < "$REMOTE_NETWORK_LIST"); do
                echo "-A vpnc_wireguard_remote -d $i -j vpnc_wireguard_mark"
            done
        fi
    fi
}

check_fw()
{
    iptables -t mangle -nL vpnc_wireguard >/dev/null 2>&1
}

stop_fw()
{
    check_fw || return

    ipt_remove_rule(){ while iptables -t $1 -C $2 2>/dev/null; do iptables -t $1 -D $2; done }
    ipt_remove_chain(){ iptables -t $1 -F $2 2>/dev/null && iptables -t $1 -X $2 2>/dev/null; }

    ipt_remove_rule "mangle" "PREROUTING -j vpnc_wireguard"
    ipt_remove_rule "mangle" "OUTPUT -j vpnc_wireguard"

    ipt_remove_chain "mangle" "vpnc_wireguard"
    ipt_remove_chain "mangle" "vpnc_wireguard_remote"
    ipt_remove_chain "mangle" "vpnc_wireguard_mark"
}

start_fw()
{
    is_started || return 1
    check_fw && return

    (
        # iptables v1.4.16.3 does not support locking functions (option -w)
        flock -x 200 || exit 1

        iptables-restore -n <<EOF
*mangle
:vpnc_wireguard - [0:0]
:vpnc_wireguard_remote - [0:0]
:vpnc_wireguard_mark - [0:0]
-A PREROUTING -j vpnc_wireguard
-A OUTPUT -j vpnc_wireguard
-A vpnc_wireguard -d $(nvram get lan_ipaddr)/$(nvram get lan_netmask) -j RETURN
-A vpnc_wireguard -d $(nvram get vpns_vnet)/24 -j RETURN
-A vpnc_wireguard -d 0.0.0.0/8 -j RETURN
-A vpnc_wireguard -d 127.0.0.0/8 -j RETURN
-A vpnc_wireguard -d 169.254.0.0/16 -j RETURN
-A vpnc_wireguard -d 224.0.0.0/4 -j RETURN
-A vpnc_wireguard -d 240.0.0.0/4 -j RETURN
-A vpnc_wireguard -p udp --dport 53 -j RETURN
-A vpnc_wireguard -p tcp --dport 53 -j RETURN
-A vpnc_wireguard -p udp --dport 123 -j RETURN
$(ipt_set_rules)
-A vpnc_wireguard_mark -j CONNMARK --restore-mark
-A vpnc_wireguard_mark -m mark --mark $FWMARK -j RETURN
-A vpnc_wireguard_mark -m conntrack --ctstate NEW -j MARK --set-mark $FWMARK
-A vpnc_wireguard_mark -m mark --mark $FWMARK -j CONNMARK --save-mark
COMMIT
EOF
        [ $? -eq 0 ] || log "firewall rules update failed"
    ) 200>/var/lock/wgc_iptables.lock
}

case $1 in
    start)
        start_wg || exit 1
    ;;

    stop)
        stop_wg
    ;;

    restart)
        stop_wg
        start_wg || exit 1
    ;;

    update)
        update_wg
    ;;

    reload)
        reload_wg
    ;;
esac

IFNAME=$IF_NAME

[ -s "$POST_SCRIPT" -a -x "$POST_SCRIPT" ] && . "$POST_SCRIPT"
