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
### https://torscan-ru.ntc.party

Bridge 217.82.105.242:9001 294A5042FD0E72006C9AB83B5D4447EC31F76B3C
Bridge 97.95.174.125:9001 3442F18139E4B6E3ABCB2598DF257909EB10699D
Bridge 102.211.56.20:9001 0153A0723F39CA78F5B60735DEC4A84E0991C5FD
Bridge 95.146.190.198:9001 66AAB03BDC3989805C986D97F9FDF29D7601D003
Bridge 185.129.62.64:9001 141C317F74D92DA44FAA072F6BFD0C98DEFF9066
Bridge 77.175.139.47:9001 0F47AC0E439D372ED2EF8E1967B5EB17F1FF66FC
Bridge 151.145.83.219:9001 D3CB91F1497F50001D61454CC3F765EACAF9EA03
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
