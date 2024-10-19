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
Enable completion of commands and arguments
Run eval "\$(isutool completion)"

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
cat "$SCRIPT_DIR/data/completion.bash"
