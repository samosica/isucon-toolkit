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
Usage: isutool $COMMAND_NAME [-h | --help] [COMMAND]
Display a help message
With a command, display the help message, otherwise describe all commands

Options:
    -h, --help            help
EOF
}

read-args(){
    COMMAND=
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            *) COMMAND="$1"; shift 1;;
        esac
    done
}

run-command(){
    local command="$SCRIPT_DIR/$1.sh"
    shift 1
    local args=("$@")

    if ! [ -e "$command" ]; then
        error "no such script: $command"
        exit 1
    fi
    $command "${args[@]}"
}

read-args "$@"

if [ -n "$COMMAND" ]; then
    run-command "$COMMAND" --help
else
    cd "$SCRIPT_DIR"
    # Note: commands starting with dot (.) are not displayed.
    #       See https://www.gnu.org/software/bash/manual/html_node/Filename-Expansion.html.
    for command in *.sh; do
        commandName=${command%.*}
        # do not pass -h instead of --help
        commandDesc=$("./${command}" --help | sed -n 2p)
        printf "%-18s    %s\n" "$commandName" "$commandDesc"
    done
fi
