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

if [ -z ${REMOTE_USER+x} ]; then
    echo "REMOTE_USER is not set" 1>&2
    exit 1
fi

if [ -z ${GIT_EMAIL+x} ]; then
    echo "GIT_EMAIL is not set" 1>&2
    exit 1
fi

if [ -z ${GIT_USERNAME+x} ]; then
    echo "GIT_USERNAME is not set" 1>&2
    exit 1
fi

if [ -z ${GITHUB_REPO+x} ]; then
    echo "GITHUB_REPO is not set" 1>&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "gh is not installed" 1>&2
    exit 1
fi

set -x

TEMPDIR=$(mktemp -d)

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

    gh repo deploy-key add "$TEMPFILE" \
       --repo "$GITHUB_REPO" \
       --title "$server" \
       --allow-write

    for s in ${SERVERS[@]}; do
        if [ "$s" != "$server" ]; then
            ssh-copy-id -f -i "$TEMPFILE" "$s"
        fi
    done

    echo "leave $server"
done

rm -r "$TEMPDIR"
