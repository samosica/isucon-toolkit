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
Usage: isutool $COMMAND_NAME [-h | --help] [-v]
Analyze a MySQL log

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

mkdir -p "$STATS_DIR"

if sudo [ -e "$MYSQL_SLOW_LOG" ]; then
    sudo pt-query-digest --config "$TOOLKIT_DIR/pt-query-digest/pt-query-digest.conf" "$MYSQL_SLOW_LOG" \
        | tee "$STATS_DIR/mysql.log";
fi
