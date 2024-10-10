#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly SCRIPT_DIR
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../util.sh"

usage(){
    local COMMAND_NAME
    COMMAND_NAME=$(basename "$0")
    COMMAND_NAME=${COMMAND_NAME%.*}
    readonly COMMAND_NAME

    cat <<EOF
Usage: isutool $COMMAND_NAME [-h | --help]
Log rotate

Options:
    -h, --help            help
    -v                    show commands to be executed
EOF
}

read-args(){
    VERBOSE=
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            -v) VERBOSE=1; shift 1;;
            *) usage; exit 1;;
        esac
    done

    readonly VERBOSE
    if [ -n "$VERBOSE" ]; then
        set -x
    fi     
}

read-args "$@"

sudo rm -f "$NGINX_ACCESS_LOG" "$MYSQL_SLOW_LOG" "$SQLITE_TRACE_LOG"
sudo nginx -s reopen
sudo mysqladmin -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" flush-logs
# this is a workaround for pprotein
sudo chmod +rx /var/log/mysql
if sudo [ -e /var/log/mysql/mysql-slow.log ]; then
    sudo chmod +r /var/log/mysql/mysql-slow.log
fi
