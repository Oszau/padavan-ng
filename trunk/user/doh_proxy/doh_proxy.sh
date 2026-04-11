#!/bin/sh

DOH_BIN="/usr/sbin/https_dns_proxy"
PID_FILE="/var/run/https_dns_proxy.pid"

LISTEN_ADDR="127.0.0.1"
LISTEN_PORT="$(nvram get doh_listen_port)"
BOOTSTRAP_DNS="$(nvram get doh_bootstrap_dns)"

# 0: standalone; 1: with dnsmasq
DOH_MODE="$(nvram get doh_mode)"

# 0: 127.0.0.1; 1: lan_ipaddr; 2: 0.0.0.0
LISTEN_MODE="$(nvram get doh_listen_mode)"

log()
{
    [ -n "$*" ] || return
    echo "$@"
    logger -t "https_dns_proxy" "$@"
}

error()
{
    log "error: $@"
    exit 1
}

start_service()
{
    if [ -f "$PID_FILE" ]; then
        echo "already running"
        return
    fi

    case "$LISTEN_MODE" in
        1) LISTEN_ADDR="$(nvram get lan_ipaddr_t)" ;;
        2) LISTEN_ADDR="0.0.0.0" ;;
    esac

    start_doh()
    {
        [ "$2" ] || return
        local bootstrap=""
        [ "$BOOTSTRAP_DNS" ] && bootstrap="-b $BOOTSTRAP_DNS"

        local res=$($DOH_BIN -p $1 -r $2 $bootstrap -a "$LISTEN_ADDR" -u nobody -g nogroup -4 -d)
        if pgrep -f "$DOH_BIN -p $1 " 2>&1 >/dev/null; then
            [ ! -f "$PID_FILE" ] && log "started, version $($DOH_BIN -V)"
            log "resolver $2, listening on $LISTEN_ADDR:$1"
            touch "$PID_FILE"
        else
            log "resolver $2 failed to start: $res"
        fi
    }

    for i in 0 1 2 3; do
        start_doh $(($LISTEN_PORT + $i)) "$(nvram get doh_server$i)"
    done

    [ ! -f "$PID_FILE" ] && error "failed to start"
}

stop_service()
{
    killall -q -SIGKILL $(basename "$DOH_BIN") && log "stopped"
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
