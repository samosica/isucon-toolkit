#!/usr/bin/env bash

set -e

CURDIR=$(cd "$(dirname "$0")" && pwd)

usage(){
    cat <<EOF
Usage: $0 [Option]...
Set up multiple servers at once

Options:
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
        echo "[error] unset variables: $missing_vars; see $CURDIR/env.sh" 1>&2
        exit 1
    fi
}

while getopts fh OPT; do
    case "$OPT" in
        h) usage
    esac
done

. "$CURDIR/env.sh"

definedcheck BASTION_USER REMOTE_USER GIT_EMAIL GIT_USERNAME GITHUB_REPO REPO_DIR

if ! command -v gh >/dev/null 2>&1; then
    echo "[error] gh is not installed" 1>&2
    exit 1
fi

set -ux

tempdir=$(mktemp -d)
trap "rm -r $tempdir" 0

REMOTE_USER_HOME="/home/$REMOTE_USER"
TOOLKIT_DIR="$REMOTE_USER_HOME/isucon-toolkit"

# Enable access to $REMOTE_USER
# (Initially, you only have access to $BASTION_USER)
for server in ${SERVERS[@]}; do
    target="$BASTION_USER@$server"

    ssh "$target" \
        "sudo mkdir -p $REMOTE_USER_HOME/.ssh && \
         sudo chmod 700 $REMOTE_USER_HOME/.ssh"
    # Copy .ssh/authorized_keys of $BASTION_USER into that of $REMOTE_USER
    ssh "$target" \
        "cat /home/$BASTION_USER/.ssh/authorized_keys | \
         sudo tee -a $REMOTE_USER_HOME/.ssh/authorized_keys >/dev/null"
    ssh "$target" \
        "sudo chmod 600 $REMOTE_USER_HOME/.ssh/authorized_keys"
done

# Retrieve members' SSH keys and send them to each server
for a in ${TEAMMATE_GITHUB_ACCOUNTS[@]}; do
    curl "https://github.com/$a.keys" -o "$tempdir/$a.pub"

    for server in ${SERVERS[@]}; do
        ssh-copy-id -f -i "$tempdir/$a.pub" "$REMOTE_USER@$server"
    done
done

for server in ${SERVERS[@]}; do
    echo "[info] enter into $server"

    target="$REMOTE_USER@$server"

    # Send this toolkit
    ssh "$target" mkdir -p "$TOOLKIT_DIR"
    rsync -av "$CURDIR/" "$target:$TOOLKIT_DIR"

    # Generate SSH key
    ssh "$target" make -f "$TOOLKIT_DIR/setup-internal.mk" ssh-setup

    # Retrieve the SSH key and add it to GitHub and the other servers
    keyfile="$tempdir/id_rsa_$server.pub"
    rsync -av "$target:$REMOTE_USER_HOME/.ssh/id_rsa.pub" "$keyfile"

    if ! gh repo deploy-key list --repo "$GITHUB_REPO" | cut -f2 | grep "$server" >/dev/null 2>&1; then
        gh repo deploy-key add "$keyfile" \
           --repo "$GITHUB_REPO" \
           --title "$server" \
           --allow-write
    else
        echo "[info] deploy key of $server is already added"
    fi

    for s in ${SERVERS[@]}; do
        if [ "$s" != "$server" ]; then
            ssh-copy-id -f -i "$keyfile" "$REMOTE_USER@$s"
        fi
    done

    # Run setup script
    ssh "$target" "echo SERVER_NAME=$server >> $TOOLKIT_DIR/env.sh"
    ssh "$target" make -f "$TOOLKIT_DIR/setup-internal.mk" setup
    ssh "$target" touch "$REMOTE_USER_HOME/.setup-lock"

    echo "[info] leave $server"
done
