#!/usr/bin/env bash

HOME=/home/$USER
REPO_DIR=$1
BRANCH=$2

set -eux

. "$HOME/env.sh"

"$HOME/sync.sh" "$REPO_DIR" "$BRANCH"

for s in ${SERVERS[@]}; do
    if [ "$s" != "$SERVER_NAME" ]; then
        ssh "$s" "$HOME/deploy.sh" "$REPO_DIR" "$BRANCH"
    fi
done
