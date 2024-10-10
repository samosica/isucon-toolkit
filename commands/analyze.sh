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
Usage: isutool $COMMAND_NAME [-h | --help] (mysql | nginx | sqlite)...
Analyze logs
With no arguments, analyze all logs

Options:
    -h, --help            help
    -v                    show commands to be executed
EOF
}

read-args(){
    VERBOSE=
    COMMANDS=()
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            -v) VERBOSE=1; shift 1;;
            *) COMMANDS+=("analyze-$1"); shift 1;;
        esac
    done

    if [ "${#COMMANDS[@]}" -eq 0 ]; then
        local script
        for script in "$SCRIPT_DIR"/analyze-*.sh; do
            local command
            command=$(basename "$script")
            command=${command%.*}
            COMMANDS+=("$command")
        done
    fi
    readonly COMMANDS

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

for command in "${COMMANDS[@]}"; do
    run-command "$command"
done
