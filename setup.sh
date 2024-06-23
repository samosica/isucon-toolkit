#!/usr/bin/env bash

set -eu

CURDIR=$(cd "$(dirname "$0")" && pwd)
readonly CURDIR

error(){
    printf "\x1b[1;31m[error]\x1b[0m %s\n" "$*" 1>&2
}

info(){
    printf "[info] %s\n" "$*"
}

usage(){
    cat <<EOF
Usage: $0 [-h | --help] [--authkey AUTHKEY] [--envfile ENVFILE]
Set up multiple servers at once

Options:
    -h, --help        help
    --authkey         specify Tailscale auth key; use reusable key when setting multiple servers up
    --envfile         specify env file (default: $(dirname "$0")/env.sh)
EOF
}

read_args(){
    ENVFILE="$CURDIR/env.sh"

    while [ $# -ge 1 ]; do
        case "$1" in
            -h | --help) usage; exit 0 ;;
            --authkey)
                [ $# -ge 2 ] || { usage && exit 1; }
                TAILSCALE_AUTHKEY=$2
                shift 2 ;;
            --envfile)
                [ $# -ge 2 ] || { usage && exit 1; }
                ENVFILE=$2
                shift 2 ;;
        esac
    done

    readonly TAILSCALE_AUTHKEY
    readonly ENVFILE
}

read_args "$@"

# shellcheck source=/dev/null
source "$ENVFILE"

defined_check(){
    set +u
    local missing_vars=()
    local name
    for name in "$@"; do
        # indirect expansion
        local val="${!name}"

        if [ -z "$val" ]; then
            missing_vars+=("$name")
        fi
    done

    if [ -n "${missing_vars[*]}" ]; then
        error "unset variables: $missing_vars; confirm the arguments passed and $ENVFILE"
        exit 1
    fi
    set -u
}

# Note: It is impossible to check if TEAMMATE_GITHUB_ACCOUNTS and SERVERS are set or not
#       If you assign the empty array to a variable, Bash recognizes the variable as an unset one
defined_check GIT_EMAIL GIT_USERNAME GITHUB_REPO REMOTE_USER

REMOTE_USER_HOME="/home/$REMOTE_USER"
readonly REMOTE_USER_HOME

distribute_member_ssh_keys(){
    local -r TEMPDIR=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -r $TEMPDIR" RETURN

    local account
    for account in "${TEAMMATE_GITHUB_ACCOUNTS[@]}"; do
        info "download $account's SSH key"
        if ! curl -s --fail "https://github.com/$account.keys" -o "$TEMPDIR/$account.pub"; then
            error "$account does not exist or does not have SSH key"
            exit 1
        fi

        local server
        for server in "${SERVERS[@]}"; do
            info "send $account's SSH key to $server"
            ssh-copy-id -f -i "$TEMPDIR/$account.pub" "$REMOTE_USER@$server"
        done
    done
}

distribute_server_ssh_keys(){
    if ! command -v gh >/dev/null 2>&1; then
        error "gh is not installed"
        exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        # shellcheck disable=SC2016
        error 'you are not logged into GitHub; run `gh auth login`'
        exit 1
    fi

    if ! gh api "repos/$GITHUB_REPO" >/dev/null 2>&1; then
        error "$GITHUB_REPO: no such repository"
        exit 1
    fi

    local -r TEMPDIR=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -r $TEMPDIR" RETURN

    local -r SERVER_KEYFILE="$REMOTE_USER_HOME/.ssh/id_ed25519.pub"
    local server
    for server in "${SERVERS[@]}"; do
        info "generate $server's SSH key"
        
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            mkdir -p $REMOTE_USER_HOME/.ssh
            if ! [ -f $REMOTE_USER_HOME/.ssh/id_ed25519 ]; then
                ssh-keygen -t ed25519 -f $REMOTE_USER_HOME/.ssh/id_ed25519 -N ''
            fi
        "

        local client_keyfile="$TEMPDIR/id_ed25519_$server.pub"
        rsync -av \
            "$REMOTE_USER@$server:$SERVER_KEYFILE" \
            "$client_keyfile"

        info "add $server's SSH key as deploy key"
        if ! gh repo deploy-key list --repo "$GITHUB_REPO" | cut -f2 | grep "$server" >/dev/null 2>&1; then
            gh repo deploy-key add \
                "$client_keyfile" \
                --repo "$GITHUB_REPO" \
                --title "$server" \
                --allow-write
        else
            info "$server's SSH key is already added as deploy key"
        fi

        local s
        for s in "${SERVERS[@]}"; do
            if [ "$s" != "$server" ]; then
                info "send $server's SSH key to $s"
                ssh-copy-id -f -i "$client_keyfile" "$REMOTE_USER@$s"
            fi
        done
    done
}

set_timezone(){
    info "set timezone"

    local -r TIMEZONE="Asia/Tokyo"
    local server
    for server in "${SERVERS[@]}"; do
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            sudo timedatectl set-timezone $TIMEZONE
            timedatectl
        "
    done
}

git_setup(){
    local -r TEMPDIR=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf $TEMPDIR" RETURN

    local -r DOTGIT="$TEMPDIR/.git"
    gh repo clone "$GITHUB_REPO" "$DOTGIT" -- --bare

    local server
    for server in "${SERVERS[@]}"; do
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            git config --global user.email $GIT_EMAIL
            git config --global user.name $GIT_USERNAME
        "

        rsync -av "$DOTGIT" "$REMOTE_USER@$server:$REPO_DIR"
        # core.logAllRefUpdates: reflog を有効にする
        # remote.origin.fetch: リモートの branch とローカルの origin/branch を対応付ける
        # remote.origin.fetch を設定しないと git fetch でリモートの変更が反映されず、git checkout branch なども失敗する
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            cd $REPO_DIR
            git config core.bare false
            git config core.logAllRefUpdates true
            git config remote.origin.fetch '+refs/heads/*:refs/heads/origin/*'
            git restore --staged --worktree . || true
        "
    done
}

install_apps(){
    cd "$CURDIR"

    if ! [ -e installer.sh ]; then
        error "installer.sh does not exist"
        exit 1
    fi

    local server
    for server in "${SERVERS[@]}"; do
        info "install apps in $server"
        ssh "$REMOTE_USER@$server" "bash -s" < installer.sh
    done    
}

send_toolkit(){
    cd "$CURDIR"

    local -r TOOLKIT_DIR="$REMOTE_USER_HOME/.isucon-toolkit"
    local server
    for server in "${SERVERS[@]}"; do
        info "send toolkit to $server"
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "mkdir -p $TOOLKIT_DIR"
        rsync -av alp pt-query-digest sync-all.sh sync.sh toolkit.mk toolkit.sh "$REMOTE_USER@$server:$TOOLKIT_DIR/"
        rsync -av "$ENVFILE" "$REMOTE_USER@$server:$TOOLKIT_DIR/"
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            echo SERVER_NAME=$server >> $TOOLKIT_DIR/env.sh
            sudo install $TOOLKIT_DIR/toolkit.sh /usr/local/bin/isutool
        "
    done
}

start_tailscale(){
    set +u
    if [ -z "$TAILSCALE_AUTHKEY" ]; then
        info "skip starting Tailscale"
    else
        local server
        for server in "${SERVERS[@]}"; do
            info "start Tailscale in $server"
            # shellcheck disable=SC2029
            ssh "$REMOTE_USER@$server" "sudo tailscale up --ssh --hostname $server --authkey $TAILSCALE_AUTHKEY"
        done
    fi
    set -u
}

distribute_member_ssh_keys
distribute_server_ssh_keys
set_timezone
git_setup
install_apps
send_toolkit
start_tailscale
