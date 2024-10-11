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
Usage: isutool $COMMAND_NAME [MYCLI_OPTION]...
Start MySQL interactive shell

$COMMAND_NAME command just executes mycli but the default values of some options
are obtained from environment variables:

    user (-u)             MYSQL_USER
    password (-p)         MYSQL_PASSWORD
    database (-D)         MYSQL_DATABASE

Options:
    --help                help
EOF
}

read-args(){
    # Note: mycli requires --host option.
    #       See https://github.com/dbcli/mycli/issues/1146.
    MYSQL_HOST=127.0.0.1
    MYSQL_DATABASE=${MYSQL_DATABASE:-}
    REST=()
    while [ $# -ge 1 ]; do
        case $1 in
            --help) usage; exit 0;;
            -h)
                if [ $# -lt 2 ]; then
                    mycli --help; exit 1
                fi
                MYSQL_HOST=$2
                shift 2;;
            --host=*) MYSQL_HOST=${1#--host=}; shift 1;;
            -u)
                if [ $# -lt 2 ]; then
                    mycli --help; exit 1
                fi
                MYSQL_USER=$2
                shift 2;;
            --user=*) MYSQL_USER=${1#--user=}; shift 1;;
            -p) MYSQL_PASSWORD=; shift 1;;
            -p*) MYSQL_PASSWORD=${1#-p}; shift 1;;
            --password) MYSQL_PASSWORD=; shift 1;;
            --password=*) MYSQL_PASSWORD=${1#--password=}; shift 1;;
            -D)
                if [ $# -lt 2 ]; then
                    mycli --help; exit 1
                fi
                MYSQL_DATABASE=$2
                shift 2;;
            --database=*) MYSQL_DATABASE=${1#--database=}; shift 1;;
            *) REST+=("$1"); shift 1;;
        esac
    done
}

run-command(){
    { set +x; } 2>/dev/null

    local command="$SCRIPT_DIR/$1.sh"
    shift 1
    local args=("$@")

    if ! [ -e "$command" ]; then
        error "no such script: $command"
        exit 1
    fi
    $command ${VERBOSE:+-v} "${args[@]}"

    if [ -n "$VERBOSE" ]; then
        set -x
    fi    
}

read-args "$@"
mycli -h "${MYSQL_HOST}" -u "${MYSQL_USER}" "-p$MYSQL_PASSWORD" \
    ${MYSQL_DATABASE+-D "$MYSQL_DATABASE"} "${REST[@]}"
