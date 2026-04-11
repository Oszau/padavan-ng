#!/bin/sh

ZEROTIER_ONE="/usr/sbin/zerotier-one"
ZEROTIER_CLI="/usr/sbin/zerotier-cli"
PID_FILE="/var/run/zerotier-one.pid"
DATA_DIR="/etc/storage/zerotier-one"

log()
{
    [ -n "$*" ] || return
    echo "$@"

    local pid
    [ -f "$PID_FILE" ] && pid="[$(cat "$PID_FILE" 2>/dev/null)]"
    logger -t "zerotier-one$pid" "$@"
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
    [ -z "$(pidof $(basename "$ZEROTIER_ONE"))" ] && return 1
    [ -f "$PID_FILE" ]
}

_start()
{
    is_started && die "already started"

    $ZEROTIER_ONE -d
    sleep 1
    if pgrep -f "$ZEROTIER_ONE" 2>&1 >/dev/null; then
        log "started, version $($ZEROTIER_ONE -v)"
        echo "waiting connection..."

        local status loop=0
        while [ $loop -lt 10 ]; do
            is_started || die
            status="$($ZEROTIER_CLI info | cut -d ' ' -f5)"
            [ "$status" = "ONLINE" ] || [ "$status" = "TUNNELED" ] && break
            loop=$((loop+1))
            sleep 1
        done

        log "$($ZEROTIER_CLI info | cut -d ' ' -f3,5 | xargs -r echo 'node:')"
        for i in "$($ZEROTIER_CLI listnetworks | grep -v '<name>' | cut -d ' ' -f3-)"; do
            [ -n "$i" ] && log "network: $i"
        done
    fi
}

_stop()
{
    killall -q -SIGKILL $(basename "$ZEROTIER_ONE") && log "stopped"
    rm -f $PID_FILE
}

_status()
{
    is_started || die "zerotier-one is not started"

    $ZEROTIER_CLI info | cut -d ' ' -f3,5 | xargs -r echo 'node:'
    $ZEROTIER_CLI listnetworks | grep -v "<name>" | cut -d ' ' -f3- | xargs -r echo 'network:'
}

case "$1" in
    start)
        _start
    ;;

    stop)
        _stop
    ;;

    restart)
        _stop
        _start
    ;;

    status)
        _status
    ;;

    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
    ;;
esac

exit 0
