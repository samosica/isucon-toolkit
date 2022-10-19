#!/usr/bin/env bash

REPO_DIR=$1
BRANCH=$2

set -eux

cd "$REPO_DIR"
git fetch
if [ -z "$BRANCH" ]; then
    git merge
else
    git checkout "$BRANCH"
    git merge "origin/$BRANCH"
fi
