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
Run a benchmark. You must specify BENCHMARK_SERVER

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

"$SCRIPT_DIR/before-bench.sh"

if [ -z "${BENCHMARK_SERVER+x}" ]; then
    error "unset variable: BENCHMARK_SERVER"
    exit 1
fi
sleep 5
ssh "$BENCHMARK_SERVER" "cd bench; ./bench"
