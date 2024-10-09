#!/usr/bin/env bash
set -eux

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
Analyze a Nginx log

Options:
    -h, --help            help
EOF
}

read-args(){
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            *) usage; exit 1;;
        esac
    done
}

read-args "$@"

# TODO: accept .yaml file
readonly ALP_CONFIG_FILE=$TOOLKIT_DIR/alp/config.yml

if ! [ -e "$ALP_CONFIG_FILE" ]; then
    error "no such file: $ALP_CONFIG_FILE"
    exit 1
fi

mkdir -p "$STATS_DIR"

if sudo [ -e "$NGINX_ACCESS_LOG" ]; then
    sudo alp ltsv \
        --file "$NGINX_ACCESS_LOG" \
        --config "$ALP_CONFIG_FILE" \
        | tee "$STATS_DIR/nginx.log"
fi
