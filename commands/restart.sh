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
Restart ISUCON application

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

restart-service(){
    if systemctl list-unit-files "$1" >/dev/null 2>&1; then
        sudo systemctl restart "$1"
    else
        error "no such service: $1"
        exit 1
    fi
}

restart-service nginx.service
restart-service mysql.service
restart-service redis.service
# TODO: add build command and call it
# cd $(REPO_DIR)/go && go build -o $(subst .service,,$(SERVICE_NAME))
sudo systemctl daemon-reload
restart-service "$SERVICE_NAME"
