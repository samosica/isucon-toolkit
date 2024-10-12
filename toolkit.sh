#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(cd "$(dirname "$(realpath "$0")")" && pwd)
readonly SCRIPT_DIR
# shellcheck source=/dev/null
source "$SCRIPT_DIR/util.sh"

usage(){
    cat <<EOF
Usage: $0 [-h | --help] COMMAND [OPTION]...

Commands:
EOF

    local command
    for command in "$SCRIPT_DIR/commands"/*.sh; do
        local commandName
        commandName=$(basename "$command")
        commandName=${commandName%.*}
        local commandDesc
        # do not pass -h instead of --help
        commandDesc=$("${command}" --help | sed -n 2p)
        printf "    %-18s    %s\n" "$commandName" "$commandDesc"
    done

    cat <<EOF

Options:
    -h, --help            help
EOF
}

read-args(){
    if [ $# -eq 0 ]; then
        usage; exit 1
    fi

    case $1 in
        -h | --help) usage; exit 0;;
    esac

    readonly COMMAND=$1
    shift 1
    readonly ARGS=("$@")
}

load-envvars(){
    set -a
    # Note: variables created after `set -a` are passed to child processes
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/env.sh"
    set +a

    export TOOLKIT_DIR=$SCRIPT_DIR
}

check-envvars(){
    local missingEnvvars=()

    local envvar
    for envvar in SERVICE_NAME REPO_DIR MYSQL_USER MYSQL_PASSWORD NGINX_ACCESS_LOG MYSQL_SLOW_LOG STATS_DIR; do
        if ! printenv "$envvar" >/dev/null ; then
            missingEnvvars+=("$envvar")
        fi
    done

    if [ "${#missingEnvvars[@]}" -ge 1 ]; then
        error "unset variables: ${missingEnvvars[*]}; fix $TOOLKIT_DIR/env.sh"
        exit 1
    fi
}

read-args "$@"
load-envvars
check-envvars

readonly COMMAND_PATH=$SCRIPT_DIR/commands/$COMMAND.sh
if ! [ -e "$COMMAND_PATH" ]; then
    error "no such command: $COMMAND"
    exit 1
fi
$COMMAND_PATH "${ARGS[@]}"
