#!/bin/sh

STUBBY_BIN="/usr/sbin/stubby"
STUBBY_CONFIG="/etc/storage/stubby/stubby.yml"
PID_FILE="/var/run/stubby.pid"

LISTEN_ADDR="127.0.0.1"
LISTEN_PORT="$(nvram get stubby_listen_port)"

# 0: 127.0.0.1; 1: lan_ipaddr; 2: 0.0.0.0
LISTEN_MODE="$(nvram get stubby_listen_mode)"

STUBBY_ROUND_ROBIN="$(nvram get stubby_round_robin)"

# 0,1: Strict; 2,3: Opportunistic
STUBBY_MODE="$(nvram get stubby_mode)"

log()
{
    [ -n "$*" ] || return
    echo "$@"
    local pid
    [ -f "$PID_FILE" ] && pid="[$(cat "$PID_FILE" 2>/dev/null)]"
    logger -t "stubby$pid" "$@"
}

error()
{
    log "error: $@"
    exit 1
}

make_config()
{
    local tls_auth="GETDNS_AUTHENTICATION_NONE"
    local dns_transport="  - GETDNS_TRANSPORT_TLS
  - GETDNS_TRANSPORT_UDP
  - GETDNS_TRANSPORT_TCP
"

    case "$STUBBY_MODE" in
        0|1)
            tls_auth="GETDNS_AUTHENTICATION_REQUIRED"
            dns_transport="  - GETDNS_TRANSPORT_TLS"
        ;;
    esac

    case "$LISTEN_MODE" in
        1) LISTEN_ADDR="$(nvram get lan_ipaddr_t)" ;;
        2) LISTEN_ADDR="0.0.0.0" ;;
    esac

    mkdir -p $(dirname "$STUBBY_CONFIG")
    cat << EOF > $STUBBY_CONFIG
resolution_type: GETDNS_RESOLUTION_STUB
tls_query_padding_blocksize: 128
edns_client_subnet_private : 1
idle_timeout: 10000
round_robin_upstreams: $STUBBY_ROUND_ROBIN
tls_authentication: $tls_auth
dns_transport_list:
$dns_transport
listen_addresses:
  - $LISTEN_ADDR@$LISTEN_PORT
upstream_recursive_servers:
EOF

    unset STUBBY_RESOLVERS
    make_config_servers()
    {
        [ "$1" ] || return
        [ "$2" ] || return

        echo "  - address_data: $2" >> $STUBBY_CONFIG
        echo "    tls_auth_name: $1" >> $STUBBY_CONFIG

        [ -n "$STUBBY_RESOLVERS" ] && STUBBY_RESOLVERS=$(echo "$STUBBY_RESOLVERS, $1") || STUBBY_RESOLVERS="$1"
    }

    for i in 0 1 2 3; do
        make_config_servers "$(nvram get stubby_server$i | tr -d ' ')" "$(nvram get stubby_server_ip$i | tr -d ' ')"
    done
}

start_service()
{
    if [ -f "$PID_FILE" ]; then
        echo "already running"
        return
    fi

    make_config

    res=$($STUBBY_BIN -i 2>&1 | grep -o "Error parsing config file")
    if [ "$res" ]; then
        error "failed to start: $res"
    else
        $STUBBY_BIN -g
        sleep 1
        if pgrep -x "$STUBBY_BIN" 2>&1 >/dev/null; then
            log "started, version $($STUBBY_BIN -V | awk '{print $2}'), listening on $LISTEN_ADDR:$LISTEN_PORT"
            [ "$STUBBY_RESOLVERS" ] && log "resolvers: $STUBBY_RESOLVERS"
        else
            error "failed to start"
        fi
    fi
}

stop_service()
{
    killall -q -SIGKILL $(basename "$STUBBY_BIN") && log "stopped"
    rm -f "$PID_FILE"
}

case "$1" in
    start)
        start_service
    ;;

    stop)
        stop_service
    ;;

    restart)
        stop_service
        start_service
    ;;

    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
    ;;
esac

exit 0
