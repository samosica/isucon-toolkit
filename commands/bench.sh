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
Usage: isutool $COMMAND_NAME [-b | --branch BRANCH] [--pull] [-h | --help] [-v]
Run a benchmark. You must specify BENCHMARK_SERVER

Options:
    -b, --branch BRANCH   switch to BRANCH
    --pull                fetch changes of a remote branch and merge it with the local one
    -h, --help            help
    -v                    show commands to be executed
EOF
}

read-args(){
    VERBOSE=
    SWITCH_BRANCH_OPTIONS=()
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            -v) VERBOSE=1; shift 1;;
            -b | --branch)
                if [ $# -le 1 ]; then
                    usage; exit 1
                fi
                SWITCH_BRANCH_OPTIONS+=("$1" "$2")
                shift 2;;
            --pull) SWITCH_BRANCH_OPTIONS+=("$1"); shift 1;;            
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
run-command before-bench "${SWITCH_BRANCH_OPTIONS[@]}"

if [ -z "${BENCHMARK_SERVER+x}" ]; then
    error "unset variable: BENCHMARK_SERVER"
    exit 1
fi
sleep 5
ssh "$BENCHMARK_SERVER" "cd bench; ./bench"
