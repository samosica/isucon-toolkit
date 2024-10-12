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
Display a help message

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

cd "$SCRIPT_DIR"
# Note: commands starting with dot (.) are not displayed.
#       See https://www.gnu.org/software/bash/manual/html_node/Filename-Expansion.html.
for command in *.sh; do
    commandName=${command%.*}
    # do not pass -h instead of --help
    commandDesc=$("./${command}" --help | sed -n 2p)
    printf "%-18s    %s\n" "$commandName" "$commandDesc"
done
