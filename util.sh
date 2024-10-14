#!/usr/bin/env bash

error(){
    printf "\x1b[1;31m[error]\x1b[0m %s\n" "$*" 1>&2
}

info(){
    printf "[info] %s\n" "$*"
}
