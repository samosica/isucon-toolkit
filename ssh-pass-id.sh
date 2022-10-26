#!/usr/bin/env bash

set -e

usage(){
    cat <<EOF
Usage: $0 -i identity_file -u user intermediate
Pass SSH public keys to remote users that you do not have direct access to

This program logs into intermediate and copy identity_file into ~user/.ssh/autho
rized_keys as root

Options:
    -h                  help
    -i identity_file    specify identity file
    -u user             specify user
EOF
}

while getopts i:u:h OPT; do
    case "$OPT" in
        i) identity_file="$OPTARG" ;;
        u) user="$OPTARG" ;;
        h) usage
           exit 0
    esac
done

shift $((OPTIND - 1))

if [ ! $# -eq 1 ]; then
    usage
    exit 1
fi

intermediate="$1"

if [ -z "$identity_file" ] || [ -z "$user" ] || [ -z "$intermediate" ]; then
    usage
    exit 1
fi

set -ux

tempfile=$(ssh "$intermediate" mktemp)
rsync "$identity_file" "$intermediate:$tempfile"
ssh "$intermediate" bash <<EOF
    set -x
    sudo mkdir -p ~$user/.ssh
    sudo chmod 700 ~$user/.ssh
    sudo chown "$user:$user" ~$user/.ssh
    cat "$tempfile" | sudo tee -a ~$user/.ssh/authorized_keys >/dev/null
    sudo chmod 600 ~$user/.ssh/authorized_keys
    sudo chown "$user:$user" ~$user/.ssh/authorized_keys
    sudo rm "$tempfile"
EOF
