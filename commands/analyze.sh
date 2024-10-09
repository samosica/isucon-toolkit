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
Usage: isutool $COMMAND_NAME [-h | --help] (mysql | nginx | sqlite)...
Analyze logs
With no arguments, analyze all logs

Options:
    -h, --help            help
EOF
}

read-args(){
    ANALYZERS=()
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            *) ANALYZERS+=("$SCRIPT_DIR/analyze-$1.sh")
        esac
        shift 1
    done

    if [ "${#ANALYZERS[@]}" -eq 0 ]; then
        readarray -d '' ANALYZERS < <(find "$SCRIPT_DIR" -type f -name 'analyze-*.sh' -print0)
    fi

    readonly ANALYZERS
}

read-args "$@"

for analyzer in "${ANALYZERS[@]}"; do
    if ! [ -e "$analyzer" ]; then
        error "no such script: $analyzer"
        exit 1
    fi
    $analyzer
done
