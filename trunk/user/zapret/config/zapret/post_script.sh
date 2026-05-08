#!/bin/sh
### Sample custom user script
### Called after executing the zapret.sh, all its variables and functions are available
### $1 - action: start/stop/reload/restart
###
### $DESYNC_MARK     - mark of processed packages, default 0x40000000
### $FILTER_MARK     - mark allowed clients, default 0x10000000
### $CLIENTS_ALLOWED - ip list allowed clients, comma separated
### $NFQUEUE_NUM     - queue number of current desync strategy
### $ISP_IF          - list of WAN interfaces separated by line breaks
### $NFQWS_BIN       - nfqws binary

post_start()
{
  # download additional domain lists
  # zapret.sh download-list
  return 0
}

post_stop()
{
  return 0
}

post_reload()
{
  return 0
}

post_restart()
{
  return 0
}

case "$1" in
  start)
    post_start
  ;;

  stop)
    post_stop
  ;;

  reload)
    post_reload
  ;;

  restart)
    post_restart
  ;;
esac
