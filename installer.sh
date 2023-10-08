#!/usr/bin/env bash

set -eux

TEMPDIR=$(mktemp -d)
readonly TEMPDIR
# shellcheck disable=SC2064
trap "rm -r $TEMPDIR" 0

cd "$TEMPDIR" || exit 1

sudo apt update

if ! command -v pt-query-digest >/dev/null 2>&1; then
    sudo apt install -y percona-toolkit
fi

if ! command -v alp >/dev/null 2>&1; then
	curl -LO https://github.com/tkuchiki/alp/releases/download/v1.0.12/alp_linux_amd64.tar.gz
	tar xf alp_linux_amd64.tar.gz
	sudo install alp /usr/local/bin
fi

if ! command -v notify_slack >/dev/null 2>&1; then
	curl -LO https://github.com/catatsuy/notify_slack/releases/download/v0.4.13/notify_slack-linux-amd64.tar.gz
	tar xf notify_slack-linux-amd64.tar.gz
	sudo install notify_slack /usr/local/bin
fi

if ! command -v unzip >/dev/null 2>&1; then
    sudo apt install -y unzip
fi

if ! command -v dsq >/dev/null 2>&1; then
    readonly VERSION="v0.23.0"
    FILE="dsq-$(uname -s | awk '{ print tolower($0) }')-x64-$VERSION.zip"
    readonly FILE
    curl -LO "https://github.com/multiprocessio/dsq/releases/download/$VERSION/$FILE"
    unzip "$FILE"
    sudo install dsq /usr/local/bin
fi

if ! command -v tree >/dev/null 2>&1; then
    sudo apt install -y tree
fi

if ! command -v graphviz >/dev/null 2>&1; then
    sudo apt install -y graphviz
fi
