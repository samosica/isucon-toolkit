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
	curl -LO https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz
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

if ! command -v duckdb >/dev/null 2>&1; then
    curl -LO https://github.com/duckdb/duckdb/releases/download/v0.9.2/duckdb_cli-linux-amd64.zip
    unzip duckdb_cli-linux-amd64.zip
    sudo install duckdb /usr/local/bin
fi

if ! command -v tree >/dev/null 2>&1; then
    sudo apt install -y tree
fi

if ! command -v graphviz >/dev/null 2>&1; then
    sudo apt install -y graphviz
fi

if ! command -v tbls >/dev/null 2>&1; then
    readonly TBLS_VERSION=1.70.2
    curl -o tbls.deb -L https://github.com/k1LoW/tbls/releases/download/v$TBLS_VERSION/tbls_$TBLS_VERSION-1_amd64.deb
    sudo dpkg -i tbls.deb
fi

if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! command -v slp >/dev/null 2>&1; then
	curl -LO https://github.com/tkuchiki/slp/releases/download/v0.2.0/slp_linux_amd64.tar.gz
	tar xf slp_linux_amd64.tar.gz
	sudo install slp /usr/local/bin
fi

if ! command -v pprotein >/dev/null 2>&1; then
    VERSION=1.2.2
    curl -LO "https://github.com/kaz/pprotein/releases/download/v$VERSION/pprotein_${VERSION}_linux_amd64.tar.gz"
    tar xf "pprotein_${VERSION}_linux_amd64.tar.gz"
    sudo cp pprotein pprotein-agent /usr/local/bin
fi
