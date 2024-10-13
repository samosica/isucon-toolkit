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
Usage: isutool $COMMAND_NAME [--pull] [-h | --help] [-v] BRANCH
Switch to a branch

Options:
    --pull                fetch changes of a remote branch and merge it with the local one
    -h, --help            help
    -v                    show commands to be executed
EOF
}

read-args(){
    VERBOSE=
    BRANCH=
    PULL=    
    while [ $# -ge 1 ]; do
        case $1 in
            -h | --help) usage; exit 0;;
            -v) VERBOSE=1; shift 1;;
            --pull) PULL=1; shift 1;;
            *) BRANCH=$1; shift 1;;
        esac
    done

    readonly VERBOSE BRANCH PULL
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
cd "$REPO_DIR"

if [ -n "$BRANCH" ] || [ -n "$PULL" ]; then
    git fetch
fi

if [ -n "$BRANCH" ]; then
    info "the current branch is $(git branch --show-current)"
    git switch "$BRANCH"
fi

if [ -n "$PULL" ]; then
    # Note: `git merge` (with no arguments) does not work when the current branch
    #       does not have the remote-tracking branches. For now, origin/(the current branch)
    #       is specified, but the part of "origin" should be parameterized.
    git merge "origin/$(git branch --show-current)"
fi
