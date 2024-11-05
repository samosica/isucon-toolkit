_isutool_list_commands(){
    for command in $(isutool help | cut -d' ' -f1); do
        printf '%s:%s\n' "$command" "$(isutool "$command" --help | sed -n 2p)"
    done
}

_isutool(){
    local state line
    # Note: I did not understand the meaning of two colons (:) preceded by a asterisk (*)
    _arguments \
        '1:command:->cmd' \
        '*:: :->args'

    case "$state" in
        cmd)
            local COMMANDS
            IFS=$'\n' COMMANDS=($(_isutool_list_commands))
            _describe command COMMANDS
            ;;
        *) _isutool_subcommand "${line[1]}";;
    esac
}

_isutool_subcommand(){
    local state line
    local -r ENVFILE="{{ ENVFILE }}"

    case "$1" in
        analyze)
            _arguments \
                '(-h --help)'{-h,--help} -v \
                '*:target:->target'
            if [ "$state" = target ]; then
                _values target mysql nginx sqlite
            fi
            ;;
        before-bench | bench)
            _arguments \
                '(-b --branch)'{-b,--branch}':branch:->branch' \
                --pull \
                '(-h --help)'{-h,--help} -v
            if [ "$state" = branch ]; then
                local REPO_DIR
                REPO_DIR=$(. "$ENVFILE" && echo "$REPO_DIR")
                IFS=$'\n' BRANCHES=($(git -C "$REPO_DIR" branch --format='%(refname:short)'))
                _describe branch BRANCHES
            fi
            ;;
        edit-command)
            _arguments \
                '(-h --help)'{-h,--help} -v \
                '*:command:->cmd'
            if [ "$state" = cmd ]; then
                IFS=$'\n' COMMANDS=($(_isutool_list_commands))
                _describe command COMMANDS
            fi
            ;;
        help)
            _arguments \
                '(-h --help)'{-h,--help} \
                '1:cmd:->cmd'
            if [ "$state" = cmd ]; then
                IFS=$'\n' COMMANDS=($(_isutool_list_commands))
                _describe command COMMANDS
            fi
            ;;
        mysql)
            _arguments '(-h --help)'{-h,--help} '*: : '
            ;;
        switch-branch)
            _arguments \
                --pull '(-h --help)'{-h,--help} -v \
                '1:branch:->branch'
            if [ "$state" = branch ]; then
                local REPO_DIR
                REPO_DIR=$(. "$ENVFILE" && echo "$REPO_DIR")
                IFS=$'\n' BRANCHES=($(git -C "$REPO_DIR" branch --format='%(refname:short)'))
                _describe branch BRANCHES
            fi
            ;;
        *)
            _arguments \
                '(-h --help)'{-h,--help} -v
            ;;
    esac
}

compdef _isutool isutool
