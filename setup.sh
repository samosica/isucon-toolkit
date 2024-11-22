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
Usage: $0 [-h | --help] [-v] [-o KEY=VALUE] [--github-token GITHUB_TOKEN] [--envfile ENVFILE]
Set up multiple servers at once

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
            *) usage; exit 1;;
        esac
    done

    if [ -z "${GITHUB_TOKEN}" ]; then
        usage; exit 1
    fi

    readonly VERBOSE SSH_OPTIONS GITHUB_TOKEN ENVFILE

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
    local server
    for server in "${SERVERS[@]}"; do
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            set -e
            sudo timedatectl set-timezone $TIMEZONE
            timedatectl
        "
    done
}

install_apps(){
    cd "$SCRIPT_DIR"

    if ! [ -e installer.sh ]; then
        error "installer.sh does not exist"
        exit 1
    fi

    local server
    for server in "${SERVERS[@]}"; do
        info "install apps in $server"
        # --login is used to search for Go directories.
        ssh "$REMOTE_USER@$server" "bash --login -s" <installer.sh
    done    
}

git_setup(){
    local server
    for server in "${SERVERS[@]}"; do
        ssh "$REMOTE_USER@$server" 'gh auth login --with-token' <<<"$GITHUB_TOKEN"

        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            set -e
            gh auth setup-git
            gh repo clone $GITHUB_REPO $REPO_DIR
            git config --global user.email $GIT_EMAIL
            git config --global user.name $GIT_USERNAME
        "
    done
}

send_toolkit(){
    cd "$SCRIPT_DIR"

    local server
    for server in "${SERVERS[@]}"; do
        info "send toolkit to $server"
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "mkdir -p $TOOLKIT_DIR"

        # the 3rd line: toolkit v1
        # the 4th line: toolkit v2
        rsync -av \
            alp pt-query-digest sync-all.sh sync.sh util.sh \
            toolkit-v1.mk toolkit-v1.sh \
            commands toolkit.sh \
            "$ENVFILE" \
            "$REMOTE_USER@$server:$TOOLKIT_DIR/"
    done
}

toolkit_setup(){
    local server
    for server in "${SERVERS[@]}"; do
        # shellcheck disable=SC2029
        ssh "$REMOTE_USER@$server" "
            set -e
            echo 'SERVER_NAME=$server' >>$TOOLKIT_DIR/env.sh
            sudo ln -s $TOOLKIT_DIR/toolkit.sh /usr/local/bin/isutool
            sudo install $TOOLKIT_DIR/toolkit-v1.sh /usr/local/bin/isutool-v1
        "

        info "append completion setting to .bashrc in $server"
        ssh "$REMOTE_USER@$server" 'cat >>~/.bashrc' <<'EOF'
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]] && \
    . /usr/share/bash-completion/bash_completion
command -v isutool >/dev/null && eval "$(isutool completion bash)"
EOF
    done
}

read_args "$@"
read_envfile
set_timezone
install_apps
git_setup
send_toolkit
toolkit_setup
