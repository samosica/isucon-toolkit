#!/usr/bin/env bash
set -eu

usage(){
    echo "$0 - set up multiple servers at once"
    echo ""
    echo "OPTIONS:"
    echo "-f: force file update"
    echo "-h: help"
    exit 0
}

force=0

while getopts fh OPT; do
    case "$OPT" in
        f) force=1 ;;
        h) usage
    esac
done

CURDIR=$(cd "$(dirname "$0")" && pwd)

. "$CURDIR/env.sh"

if [ -z "$REMOTE_USER" ]; then
    echo "REMOTE_USER is not set"
    exit 1
fi

if [ -z "$GIT_EMAIL" ]; then
    echo "GIT_EMAIL is not set"
    exit 1
fi

if [ -z "$GIT_USERNAME" ]; then
    echo "GIT_USERNAME is not set"
    exit 1
fi

set -x

TEMPDIR=$(mktemp -d)

for server in ${SERVERS[@]}; do
    echo "enter into $server"

    REMOTE_HOME="/home/$REMOTE_USER"
    TOOLKIT_DIR="$REMOTE_HOME/isucon-toolkit"

    # Send this toolkit
    ssh "$server" mkdir -p "$TOOLKIT_DIR"
    rsync -av "$CURDIR/" "$server:$TOOLKIT_DIR"
    ssh "$server" "echo SERVER_NAME=$server >> $TOOLKIT_DIR/env.sh"
    ssh "$server" make -f "$TOOLKIT_DIR/setup-internal.mk" setup "force=$force"

    TEMPFILE="$TEMPDIR/id_rsa_$server.pub"

    # SSH key exchange
    rsync -av "$server:$REMOTE_HOME/.ssh/id_rsa.pub" "$TEMPFILE"
    for s in ${SERVERS[@]}; do
        if [ "$s" != "$server" ]; then
            ssh-copy-id -f -i "$TEMPFILE" "$s"
        fi
    done

    echo "leave $server"
done

rm -r "$TEMPDIR"
