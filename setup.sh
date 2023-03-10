#!/usr/bin/env bash

set -e

CURDIR=$(cd "$(dirname "$0")" && pwd)

definedcheck(){
    local missing_vars=()
    for name in "$@"; do
        local val="${!name}"

        if [ -z "$val" ]; then
            missing_vars+=("$name")
        fi
    done

    if [ -n "${missing_vars[*]}" ]; then
        echo "[error] unset variables: $missing_vars; see $CURDIR/env.sh" 1>&2
        exit 1
    fi
}

usage(){
    cat <<EOF
Usage: $0 [Option]...
Set up multiple servers at once

Options:
    -h    help
EOF
}

while getopts h OPT; do
    case "$OPT" in
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# shellcheck source=/dev/null
. "$CURDIR/env.sh"

definedcheck REMOTE_USER GIT_EMAIL GIT_USERNAME GITHUB_REPO REPO_DIR

if ! command -v gh >/dev/null 2>&1; then
    printf "\x1b[1;31m[error]\x1b[0m gh is not installed\n" 1>&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    # shellcheck disable=SC2016
    printf '\x1b[1;31m[error]\x1b[0m you are not logged into GitHub; run `gh auth login`\n' 1>&2
    exit 1
fi

if ! gh api "repos/$GITHUB_REPO" >/dev/null 2>&1; then
    printf "\x1b[1;31m[error]\x1b[0m %s: no such repository\n" "$GITHUB_REPO" 1>&2
    exit 1
fi

set -ux

tempdir=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -r $tempdir" 0

# Retrieve members' SSH keys and send them to each server
for a in "${TEAMMATE_GITHUB_ACCOUNTS[@]}"; do
    if ! curl --fail "https://github.com/$a.keys" -o "$tempdir/$a.pub"; then
        printf '\x1b[1;31m[error]\x1b[0m %s: no such account\n' "$a" 1>&2
        exit 1
    fi

    for server in "${SERVERS[@]}"; do
        ssh-copy-id -f -i "$tempdir/$a.pub" "$REMOTE_USER@$server"
    done
done

REMOTE_USER_HOME="/home/$REMOTE_USER"
TOOLKIT_DIR="$REMOTE_USER_HOME/isucon-toolkit"

for server in "${SERVERS[@]}"; do
    echo "[info] enter into $server"

    target="$REMOTE_USER@$server"

    # shellcheck disable=SC2029
    if [ "$(ssh "$target" "test -e $REMOTE_USER_HOME/.setup-lock; echo \$?")" -eq 0 ]; then
        echo "[info] $server is ready; skip setup"
        continue
    fi

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

    for s in "${SERVERS[@]}"; do
        if [ "$s" != "$server" ]; then
            ssh-copy-id -f -i "$keyfile" "$REMOTE_USER@$s"
        fi
    done

    # Run setup script
    # shellcheck disable=SC2029
    ssh "$target" "echo SERVER_NAME=$server >> $TOOLKIT_DIR/env.sh"
    ssh "$target" make -f "$TOOLKIT_DIR/setup-internal.mk" setup
    # shellcheck disable=SC2029
    ssh "$target" touch "$REMOTE_USER_HOME/.setup-lock"

    echo "[info] leave $server"
done
