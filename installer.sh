#!/usr/bin/env bash

set -eux

error(){
    printf "\x1b[1;31m[error]\x1b[0m %s\n" "$*" 1>&2
}

info(){
    printf "[info] %s\n" "$*"
}

compare-versions(){
    local major1 minor1 patch1
    local major2 minor2 patch2
    IFS='.' read -r major1 minor1 patch1 < <(echo "${1#v}")
    IFS='.' read -r major2 minor2 patch2 < <(echo "${2#v}")

    local diff_major=$(("$major1" - "$major2"))
    local diff_minor=$(("$minor1" - "$minor2"))
    local diff_patch=$(("$patch1" - "$patch2"))

    if ! [ "$diff_major" -eq 0 ]; then
        echo "$diff_major"
    elif ! [ "$diff_minor" -eq 0 ]; then
        echo "$diff_minor"
    else
        echo "$diff_patch"
    fi
}

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

if ! command -v python3 >/dev/null 2>&1; then
    sudo apt install -y python3
fi

if ! python3 -m pip >/dev/null 2>&1; then
    sudo apt install -y python3-pip
fi

if ! command -v mycli >/dev/null 2>&1; then
    sudo apt install -y mycli
fi

readonly GO_VERSION=go1.23.2
if ! command -v go >/dev/null 2>&1; then
    INSTALL_GO=1
else
    currentGoVersion="$(go version | cut -d' ' -f3)"
    if [ "$(compare-versions "${currentGoVersion#go}" "${GO_VERSION#go}")" -lt 0 ]; then
        INSTALL_GO=1
    fi
fi

if [ -n "${INSTALL_GO:+x}" ]; then
    if [ -d /usr/local/go-backup ]; then
        error "Go is already updated. If you want to retry, remove /usr/local/go-backup first"
        exit 1
    fi
    if [ -d /usr/local/go ]; then
        sudo mv /usr/local/go{,-backup}
    fi

    curl -LO "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz"
    sudo tar -C /usr/local -xzf "${GO_VERSION}.linux-amd64.tar.gz"
    # shellcheck disable=SC2016
    echo 'export PATH=/usr/local/go/bin:"$PATH"' >~/.profile
    currentGoVersion="$(/usr/local/go/bin/go version | cut -d' ' -f3)"
    if [ "$currentGoVersion" != "$GO_VERSION" ]; then
        error "the expected version of Go is $GO_VERSION, but the actual one is $currentGoVersion"
        if [ -d /usr/local/go-backup ]; then
            sudo rm -rf /usr/local/go
            sudo mv /usr/local/go{-backup,}
        fi
        exit 1
    fi
fi
