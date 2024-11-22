#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly SCRIPT_DIR

error(){
    printf "\x1b[1;31m[error]\x1b[0m %s\n" "$*" 1>&2
}

info(){
    printf "[info] %s\n" "$*"
}

usage(){
    cat <<EOF
Usage: $0 [-h | --help] [-v] [-o KEY=VALUE] [--github-token GITHUB_TOKEN] [--envfile ENVFILE] SERVER
Set up a single server for competitors

You can also specify GITHUB_TOKEN as an environment variable.

Options:
    -h, --help        help
    -v                show commands to be executed    
    -o                specify SSH option; see ssh_config(5)
    --github-token    specify GitHub personal access token
    --envfile         specify env file (default: $(dirname "$0")/env.sh)
EOF
}

read_args(){
    VERBOSE=
    SSH_OPTIONS=()
    GITHUB_TOKEN="${GITHUB_TOKEN-}"
    ENVFILE="$SCRIPT_DIR/env.sh"
    SERVER=

    while [ $# -ge 1 ]; do
        case "$1" in
            -h | --help) usage; exit 0;;
            -v) VERBOSE=1; shift 1;;
            -o)
                [ $# -ge 2 ] || { usage && exit 1; }
                SSH_OPTIONS+=("$1" "$2")
                shift 2;;
            --github-token)
                [ $# -ge 2 ] || { usage && exit 1; }
                GITHUB_TOKEN=$2
                shift 2;;
            --envfile)
                [ $# -ge 2 ] || { usage && exit 1; }
                ENVFILE=$2
                shift 2;;
            *)
                if [ -n "$SERVER" ]; then
                    error 'cannot setup multiple servers at once'
                    exit 1
                fi
                SERVER=$1
                shift 1;;
        esac
    done

    if [ -z "${GITHUB_TOKEN}" ]; then
        usage; exit 1
    fi

    readonly VERBOSE SSH_OPTIONS GITHUB_TOKEN ENVFILE SERVER

    if [ -n "$VERBOSE" ]; then
        set -x
    fi    
}

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

read_envfile(){
    # shellcheck source=/dev/null
    source "$ENVFILE"

    defined_check GIT_EMAIL GIT_USERNAME GITHUB_REPO REMOTE_USER

    readonly REMOTE_USER_HOME="/home/$REMOTE_USER"
    readonly TOOLKIT_DIR="$REMOTE_USER_HOME/.isucon-toolkit"
}

# override ssh with SSH_OPTIONS
ssh(){
    command ssh "${SSH_OPTIONS[@]}" "$@"
}

set_timezone(){
    info "set timezone"

    local -r TIMEZONE="Asia/Tokyo"
    # shellcheck disable=SC2029
    ssh "$REMOTE_USER@$SERVER" "
        set -e
        sudo timedatectl set-timezone $TIMEZONE
        timedatectl
    "
}

install_apps(){
    cd "$SCRIPT_DIR"

    if ! [ -e installer.sh ]; then
        error "installer.sh does not exist"
        exit 1
    fi

    info "install apps in $SERVER"
    # --login is used to search for Go directories.
    ssh "$REMOTE_USER@$SERVER" "bash --login -s" <installer.sh
}

git_setup(){
    ssh "$REMOTE_USER@$SERVER" 'gh auth login --with-token' <<<"$GITHUB_TOKEN"

    # Note: --bare and the subsequent commands are required because $REPO_DIR has some files.
    # core.logAllRefUpdates: reflog を有効にする
    # remote.origin.fetch: リモートの branch とローカルの origin/branch を対応付ける
    # remote.origin.fetch を設定しないと git fetch でリモートの変更が反映されず、git checkout branch なども失敗する
    # shellcheck disable=SC2029
    ssh "$REMOTE_USER@$SERVER" "
        set -e
        gh auth setup-git
        git config --global user.email $GIT_EMAIL
        git config --global user.name $GIT_USERNAME
        cd '$REPO_DIR'
        gh repo clone '$GITHUB_REPO' .git -- --bare
        git config core.bare false
        git config core.logAllRefUpdates true
        git config remote.origin.fetch '+refs/heads/*:refs/heads/origin/*'
        git restore --staged --worktree . || true
    "
}

send_toolkit(){
    cd "$SCRIPT_DIR"

    info "send toolkit to $SERVER"
    # shellcheck disable=SC2029
    ssh "$REMOTE_USER@$SERVER" "mkdir -p $TOOLKIT_DIR"

    # the 3rd line: toolkit v1
    # the 4th line: toolkit v2
    rsync -av \
        alp pt-query-digest util.sh \
        toolkit-v1.mk toolkit-v1.sh \
        commands toolkit.sh \
        "$ENVFILE" \
        "$REMOTE_USER@$SERVER:$TOOLKIT_DIR/"
}

toolkit_setup(){
    # shellcheck disable=SC2029
    ssh "$REMOTE_USER@$SERVER" "
        set -e
        echo 'SERVER_NAME=$SERVER' >>$TOOLKIT_DIR/env.sh
        sudo ln -s $TOOLKIT_DIR/toolkit.sh /usr/local/bin/isutool
        sudo install $TOOLKIT_DIR/toolkit-v1.sh /usr/local/bin/isutool-v1
    "

    info "append completion setting to .bashrc in $SERVER"
    ssh "$REMOTE_USER@$SERVER" 'cat >>~/.bashrc' <<'EOF'
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]] && \
    . /usr/share/bash-completion/bash_completion
command -v isutool >/dev/null && eval "$(isutool completion bash)"
EOF
}

read_args "$@"
read_envfile
set_timezone
install_apps
git_setup
send_toolkit
toolkit_setup
