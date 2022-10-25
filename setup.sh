#!/usr/bin/env bash

set -e

CURDIR=$(cd "$(dirname "$0")" && pwd)

usage(){
    cat <<EOF
Usage: $0 [Option]...
Set up multiple servers at once

Options:
    -f    force file update
    -h    help
EOF
    exit 0
}

definedcheck(){
    local missing_vars=()
    for name in "$@"; do
        local val="${!name}"

        if [ -z "$val" ]; then
            missing_vars+=$name
        fi
    done

    if [ -n "${missing_vars}" ]; then
        echo "unset variables: $missing_vars; see $CURDIR/env.sh" 1>&2
        exit 1
    fi
}

force=0

while getopts fh OPT; do
    case "$OPT" in
        f) force=1 ;;
        h) usage
    esac
done

. "$CURDIR/env.sh"

definedcheck REMOTE_USER GIT_EMAIL GIT_USERNAME GITHUB_REPO

if ! command -v gh >/dev/null 2>&1; then
    echo "gh is not installed" 1>&2
    exit 1
fi

set -ux

TEMPDIR=$(mktemp -d)
trap "rm -r $TEMPDIR" 0

for a in ${TEAMMATE_GITHUB_ACCOUNTS[@]}; do
    curl "https://github.com/$a.keys" -o "$TEMPDIR/$a.pub"
done

for server in ${SERVERS[@]}; do
    echo "enter into $server"

    REMOTE_HOME="/home/$REMOTE_USER"
    TOOLKIT_DIR="$REMOTE_HOME/isucon-toolkit"

    # Send this toolkit
    ssh "$server" mkdir -p "$TOOLKIT_DIR"
    rsync -av "$CURDIR/" "$server:$TOOLKIT_DIR"
    ssh "$server" "echo SERVER_NAME=$server >> $TOOLKIT_DIR/env.sh"
    ssh "$server" make -f "$TOOLKIT_DIR/setup-internal.mk" setup "force=$force"

    # SSH key exchange
    for a in ${TEAMMATE_GITHUB_ACCOUNTS[@]}; do
        ssh-copy-id -f -i "$TEMPDIR/$a.pub" "$server"
    done

    TEMPFILE="$TEMPDIR/id_rsa_$server.pub"

    rsync -av "$server:$REMOTE_HOME/.ssh/id_rsa.pub" "$TEMPFILE"

    if ! gh repo deploy-key list --repo "$GITHUB_REPO" | cut -f2 | grep "$server" >/dev/null 2>&1; then
        gh repo deploy-key add "$TEMPFILE" \
           --repo "$GITHUB_REPO" \
           --title "$server" \
           --allow-write
    else
        echo "deploy key of $server is already added"
    fi

    for s in ${SERVERS[@]}; do
        if [ "$s" != "$server" ]; then
            ssh-copy-id -f -i "$TEMPFILE" "$s"
        fi
    done

    echo "leave $server"
done
