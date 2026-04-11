#!/bin/sh

DNSCRYPT_BIN="/usr/sbin/dnscrypt-proxy"
PID_FILE="/var/run/dnscrypt-proxy.pid"

LISTEN_ADDR="127.0.0.1"
LISTEN_PORT="$(nvram get dnscrypt_listen_port)"

# 0: standalone; 1: with dnsmasq
DNSCRYPT_MODE="$(nvram get dnscrypt_mode)"

# 0: 127.0.0.1; 1: lan_ipaddr; 2: 0.0.0.0
LISTEN_MODE="$(nvram get dnscrypt_listen_mode)"

log()
{
    [ -n "$*" ] || return
    echo "$@"
    logger -t "dnscrypt-proxy" "$@"
}

error()
{
    log "error: $@"
    exit 1
}

func_start()
{
    if [ -f "$PID_FILE" ]; then
        echo "already running"
        return
    fi

    case "$LISTEN_MODE" in
        1) LISTEN_ADDR="$(nvram get lan_ipaddr_t)" ;;
        2) LISTEN_ADDR="0.0.0.0" ;;
    esac

    start_proxy()
    {
        [ "$2" ] || return

        local res=$($DNSCRYPT_BIN -R $2 -a $LISTEN_ADDR:$1 -u nobody -d -e 4096 -m 3 2>&1)
        if pgrep -f "$DNSCRYPT_BIN -R $2 " 2>&1 >/dev/null; then
            [ ! -f "$PID_FILE" ] && log "started, version 1.9.5"
            log "resolver $2, listening on $LISTEN_ADDR:$1"
            touch "$PID_FILE"
        else
            log "resolver $2 failed to start: $(echo "$res" | sed -n 's/.*\[ERROR\] //p')"
        fi
    }

    for i in 0 1 2 3; do
        start_proxy $(($LISTEN_PORT+$i)) "$(nvram get dnscrypt_resolver$i)"
    done

    [ ! -f "$PID_FILE" ] && error "failed to start"
}

func_stop()
{
    killall -q -SIGKILL $(basename "$DNSCRYPT_BIN") && log "stopped"
    rm -f "$PID_FILE"
}

case "$1" in
    start)
        func_start
    ;;

    stop)
        func_stop
    ;;

    restart)
        func_stop
        func_start
    ;;

    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
    ;;
esac

exit 0
