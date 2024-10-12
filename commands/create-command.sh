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
Usage: isutool $COMMAND_NAME [-h | --help] [-v] COMMAND
Create command

Options:
    -h, --help            help
    -v                    show commands to be executed
EOF
}

read-args(){
    VERBOSE=
    COMMAND=
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            -v) VERBOSE=1; shift 1;;
            *) COMMAND="$1"; shift 1;;
        esac
    done

    readonly VERBOSE
    if [ -n "$VERBOSE" ]; then
        set -x
    fi

    readonly COMMAND
    if [ -z "$COMMAND" ]; then
        usage; exit 1
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

commandPath="$SCRIPT_DIR/$COMMAND.sh"
if [ -e "$commandPath" ]; then
    error "$COMMAND already exists"
    exit 1
fi

read -r -p "Description: " description

cp "$SCRIPT_DIR/data/command.template" "$commandPath"
sed -i "s/{{ DESCRIPTION }}/$description/" "$commandPath"
chmod +x "$commandPath"
