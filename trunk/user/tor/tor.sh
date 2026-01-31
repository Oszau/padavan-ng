#!/bin/sh

TOR_BIN="/usr/sbin/tor"
PID_FILE="/var/run/tor.pid"
PID_WAIT_SYNC_FILE="/var/run/tor_wait_sync.pid"

DATA_DIR="/tmp/tor"
unset OPT
[ -d "/opt/tmp" ] && OPT="/opt"

GEOIP_DIR="/usr/share/tor"
CONFIG_DIR="/etc/storage/tor"
CONFIG_FILE="$CONFIG_DIR/torrc"
TOR_REMOTE_LIST="$CONFIG_DIR/remote_network.list"
TOR_NETWORK_IPV4="172.16.0.0/12"
CONTROL_PORT=9051
DNS_PORT=9053
TRANS_PORT=9040

NV_TOR_ENABLED="$(nvram get tor_enable)"

# 0 - disabled, 1 - redirect allowed remote, 2 - redirect all
NV_TOR_PROXY_MODE="$(nvram get tor_proxy_mode)"

# get comma separated lists for nvram
NV_TOR_CLIENTS="$(nvram get tor_clients_allowed | tr -s ' ,' '\n')"
NV_IPSET_LIST="$(nvram get tor_ipset_allowed | tr -s ' ,' '\n')"

TOR_IPSET_CLIENTS="tor.clients"
TOR_IPSET_REMOTE="tor.remote"

DNSMASQ_IPSET="tor"

LAN_IP=$(nvram get lan_ipaddr)
[ "$LAN_IP" ] || LAN_IP="192.168.1.1"

unset IPSET
[ -x /sbin/ipset ] && IPSET=1

log()
{
    [ -n "$*" ] || return
    echo "$@"

    local pid
    [ -f "$PID_FILE" ] && pid="[$(cat "$PID_FILE" 2>/dev/null)]"
    logger -t "Tor$pid" "$@"
}

error()
{
    log "error: $@"
    exit 1
}

die()
{
    [ -n "$*" ] && echo "$@" >&2
    exit 1
}

is_started()
{
    [ -z "$(pidof $(basename "$TOR_BIN"))" ] && return 1
    [ -f "$PID_FILE" ]
}

func_create_config()
{
    [ ! -d "$CONFIG_DIR" ] && mkdir -p $CONFIG_DIR
    chmod 755 "$CONFIG_FILE"

    [ -s "$CONFIG_FILE" ] && return

    cat > "$CONFIG_FILE" <<EOF
### https://www.torproject.org/docs/tor-manual.html
### reserved: network $TOR_NETWORK_IPV4, ports 80,443/TCP

# ExcludeExitNodes {RU}, {UA}, {BY}, {KZ}, {MD}, {AZ}, {AM}, {GE}, {LY}, {LT}, {TM}, {UZ}, {EE}
# StrictNodes 1

SocksPort ${LAN_IP}:9050
HTTPTunnelPort ${LAN_IP}:8181

# custom Padavan firmware option: prevent microdescs saved in Datadirectory
NotSaveMicrodescs 1

# TrackHostExits .
DormantTimeoutEnabled 0
NumEntryGuards 8
NewCircuitPeriod 30
LongLivedPorts 80,443
DormantCanceledByStartup 1
MaxCircuitDirtiness 120
KeepalivePeriod 60
HiddenServiceStatistics 0
ClientOnly 1
ExitRelay 0
ExitPolicy reject *:*
ExitPolicy reject6 *:*
AutomapHostsOnResolve 1
Log notice syslog
AvoidDiskWrites 1
UseBridges 1

### https://bridges.torproject.org/bridges?transport=vanilla
### https://github.com/ValdikSS/tor-relay-scanner

Bridge 93.234.205.239:9001 1BAFC3BFD1E39CB6F759195A8907EA79A9496FE7
Bridge 195.52.63.88:9001 2946C155809496D43A3ED91D649A7AB9004CF86A
Bridge 79.195.179.11:9001 E0A4547E607DBDB46591CC0DF74980DE450E08F9
Bridge 84.144.99.27:9003 48CF1DEA5F6A71BE26E302D4BC61235C861C28D9
Bridge 87.122.39.73:443 E788F5EAD36D47C14E43C289EB4DE4DB468BAC19
Bridge [2a12:a800:11:1:192:159:99:162]:7430 DC9169A6A33118A3AAB463CF52093D9195464D29
Bridge [2001:67c:289c:2::39]:81 55277EB96F22D4DD6A8048D7945078E0C5BECA3D
Bridge [2a03:e600:100::11]:9003 EFF9450F68918776F870BBC554F8E3A7D6E1C953
Bridge [2a0b:f4c2::]:9003 8C582D20C1362A37CB8B8321A5D745578FE01977
Bridge [2a0b:f4c2:1::137]:10137 C028378B070FC72B2AB9E5C93F6E292D841B9EAC
Bridge [2a04:52c0:115:fed3::1]:9001 F732303DAE01A4EF9AF28127425950B494C59927
Bridge [2a0d:bbc7::f816:3eff:fe18:f410]:853 ED2E34869CCCBCE9321DEBBB957507A85A155CEF
Bridge [2a0b:4142:218::2]:9001 0858C3E9183DC93C3E31026220BA6BA92273E7C4
Bridge [2602:f9f3:0:2::2f5]:9001 0D13B5883BD6B942775CF5841257C8F1B5042F1F
Bridge [2a0c:2500:571:6bf:f10d:eb5:1b24:f5d1]:443 873914828C1161F02771F51AC7D97456317FC041
Bridge [2003:e7:2f2e:2001:be24:11ff:fe4b:9928]:9001 E6ACCCC7BE3775C3FF10348B881E37B6A6981A66
Bridge [2a12:a800:8:1:45:94:31:68]:143 51FAFEABB266B7E4E1EB4E6120DF2D7F719157EB
Bridge [2001:41d0:403:585a::]:9005 F93DC96A3010079BDCE904856036588C17304BBF
Bridge [2a00:1b88:4::2]:443 A319D6447B2B4107477E126EE4A2B7C38125149E
EOF
    chmod 644 "$CONFIG_FILE"
}

tor_control()
{
    nc -z 127.0.0.1 $CONTROL_PORT >/dev/null 2>&1 || die
    [ -n "$1" ] || return
    printf 'AUTHENTICATE ""\r\n%s\r\nQUIT\r\n' "$1" \
        | nc -w 5 127.0.0.1 $CONTROL_PORT 2>/dev/null
}

tor_get_status()
{
    tor_control 'GETINFO status/bootstrap-phase' \
        | sed -n 's|250-status/||p'
}

tor_ready() {
    local status="$(tor_get_status)"
    [ -n "$status" ] || return 1

    echo "$status" \
        | sed 's| \([A-Z]\)|\n\1|g' \
        | grep -E 'PROGRESS=|WARNING=|HOSTADDR=|SUMMARY=' \
        | xargs -r -d'\n'
    echo $status | grep -q 'PROGRESS=100'
}

tor_waiting_bootstrap()
{
    local loop=0
    local pid="$(cat $PID_FILE 2>/dev/null)"

    echo "waiting bootstrapping..."
    while ! tor_ready && [ $loop -lt 60 ]; do
        is_started || die
        [ ! "$pid" = "$(cat $PID_FILE 2>/dev/null)" ] && die
        loop=$((loop+1))
        sleep 5
    done
    echo "done"

    rm -f "$PID_WAIT_SYNC_FILE"
    sync && sysctl -q vm.drop_caches=3
    start_redirect
}

start_tor()
{
    is_started && die "already started"

    [ ! -f "$CONFIG_FILE" ] && func_create_config

    if [ -d "/opt/share/tor" ]
    then
        mount | grep -q $GEOIP_DIR || mount --bind /opt/share/tor $GEOIP_DIR
    fi

    log "started, data directory: ${OPT}${DATA_DIR}"
    rm -rf ${OPT}${DATA_DIR}
    rm -rf $DATA_DIR

    # 0.0.0.0 for TransPort, because REDIRECT between interfaces does not work
    $TOR_BIN --RunAsDaemon 1 \
        --DataDirectory ${OPT}${DATA_DIR} \
        --ControlPort $CONTROL_PORT \
        --CookieAuthentication 0 \
        --DNSPort $DNS_PORT \
        --VirtualAddrNetworkIPv4 $TOR_NETWORK_IPV4 \
        --TransPort 0.0.0.0:$TRANS_PORT \
        --PidFile $PID_FILE

    if [ "$?" -eq 0 ]; then
        [ "$NV_TOR_PROXY_MODE" = "0" -o -z "$NV_TOR_PROXY_MODE" ] && return
        sleep 1
        tor_waiting_bootstrap &
        echo $! > "$PID_WAIT_SYNC_FILE"
    fi
}

stop_tor()
{
    stop_redirect
    killall -q -SIGKILL $(basename "$TOR_BIN") && log "stopped"

    if mountpoint -q $GEOIP_DIR ; then
        umount -l $GEOIP_DIR
    fi

    rm -rf ${OPT}${DATA_DIR}
    rm -rf $DATA_DIR
    rm -f $PID_FILE
    [ -f "$PID_WAIT_SYNC_FILE" ] \
        && kill "$(cat "$PID_WAIT_SYNC_FILE")" 2>/dev/null \
        && rm -f "$PID_WAIT_SYNC_FILE"
}

reload_tor()
{
    is_started || return

    kill -SIGHUP $(cat "$PID_FILE")
}

### transparent proxy

filter_ipv4()
{
    grep -E -x '^[[:space:]]*((25[0-5]|2[0-4][0-9]|1[0-9]{2}|0?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|0?[0-9]{1,2})(/(3[0-2]|[12]?[0-9]))?[[:space:]]*$' \
        | sed -E 's#/32|/0##g' | sort | uniq
}

fill_ipset()
{
    # $1: "list" - file list; "" - var with line break

    local mode="$1"
    local name="$2"
    local list="$3"

    [ -n "$name" ] || return
    ipset -q -N $name nethash \
        && log "ipset '$name' created successfully"
    ipset -q flush $name

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

create_ipset()
{
    [ -z "$IPSET" ] && return

    ipset -q -N $DNSMASQ_IPSET nethash timeout 21600 \
        && log "ipset '$DNSMASQ_IPSET' with timeout 21600 created successfully"

    fill_ipset "nv" "$TOR_IPSET_CLIENTS" "$NV_TOR_CLIENTS"
    fill_ipset "list" "$TOR_IPSET_REMOTE" "$TOR_REMOTE_LIST"

    local name
    for name in $NV_IPSET_LIST; do
        ipset -q -N $name nethash \
            && log "ipset '$name' created successfully"
    done
}

stop_redirect()
{
    ipt_remove_rule(){ while iptables -t $1 -C $2 2>/dev/null; do iptables -t $1 -D $2; done }
    ipt_remove_chain(){ iptables -t $1 -F $2 2>/dev/null && iptables -t $1 -X $2 2>/dev/null; }

    ipt_remove_rule "raw" "PREROUTING -p tcp -m multiport --dports 80,443 -j tor_proxy"
    ipt_remove_rule "nat" "PREROUTING -p tcp -m mark --mark $TRANS_PORT -j REDIRECT --to-port $TRANS_PORT"

    ipt_remove_chain "raw" "tor_proxy"
    ipt_remove_chain "raw" "tor_remote"
    ipt_remove_chain "raw" "tor_mark"
}

make_rules()
{
    local i

    if [ -n "$NV_TOR_CLIENTS" ]; then
        if [ -n "$IPSET" ]; then
            echo "-A tor_proxy -m set --match-set $TOR_IPSET_CLIENTS src -j tor_remote"
        else
            for i in $NV_TOR_CLIENTS; do
                echo "-A tor_proxy -s $i -j tor_remote"
            done
        fi
    else
        echo "-A tor_proxy -j tor_remote"
    fi

    for i in \
        0.0.0.0/8 127.0.0.0/8 169.254.0.0/16 \
        224.0.0.0/4 240.0.0.0/4 100.64.0.0/10 \
        10.0.0.0/8 192.168.0.0/16 \
        198.18.0.0/15 192.88.99.0/24 192.0.0.0/24 \
        192.0.2.0/24 198.51.100.0/24 203.0.113.0/24
    do
        echo "-A tor_remote -d $i -j RETURN"
    done

    if [ "$NV_TOR_PROXY_MODE" = "1" ]; then
        if [ -n "$IPSET" ]; then
            for i in $TOR_IPSET_REMOTE $NV_IPSET_LIST; do
                echo "-A tor_remote -m set --match-set $i dst -j tor_mark"
            done
        else
            for i in $(filter_ipv4 < "$TOR_REMOTE_LIST"); do
                echo "-A tor_remote -d $i -j tor_mark"
            done
        fi
    else
        echo "-A tor_remote -j tor_mark"
    fi
}

start_redirect()
{
    stop_redirect

    is_started || return 1
    [ "$NV_TOR_PROXY_MODE" = "0" -o -z "$NV_TOR_PROXY_MODE" ] && return
    [ -f "$PID_WAIT_SYNC_FILE" ] && return

    create_ipset

    # using the raw table due to a very old kernel
    iptables-restore -n <<EOF
*nat
-A PREROUTING -p tcp -m mark --mark $TRANS_PORT -j REDIRECT --to-ports $TRANS_PORT
COMMIT
*raw
:tor_proxy - [0:0]
:tor_remote - [0:0]
:tor_mark - [0:0]
-A PREROUTING -p tcp -m multiport --dports 80,443 -j tor_proxy
$(make_rules)
-A tor_remote -d $TOR_NETWORK_IPV4 -j tor_mark
-A tor_mark -j MARK --set-mark $TRANS_PORT
COMMIT
EOF
    [ $? -eq 0 ] || error "firewall rules update failed"
}


case "$1" in
    start)
        start_tor
    ;;

    stop)
        stop_tor
    ;;

    restart)
        stop_tor
        start_tor
    ;;

    reload)
        reload_tor
    ;;

    update)
        start_redirect
    ;;

    status)
        tor_get_status
    ;;

    control)
        tor_control "$2"
    ;;

    config|create-config)
        [ ! -f "$CONFIG_FILE" ] && func_create_config
    ;;

    *)
        echo "Usage: $0 {start|stop|restart|reload|update|status|create-config|control <command>}"
        exit 1
    ;;
esac

exit 0
