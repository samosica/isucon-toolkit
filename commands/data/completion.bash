_isutool(){
    local -r REPO_DIR="{{ REPO_DIR }}"

    # shellcheck disable=SC2034
    local cur prev words cword split
    _init_completion || return

    local COMMANDS BRANCHES
    if [ "$cword" -eq 1 ]; then
        readarray -t COMMANDS < <(isutool help | cut -d' ' -f1)
        readarray -t COMPREPLY < <(compgen -W "${COMMANDS[*]}" -- "$cur")
        return
    fi

    COMPREPLY=()
    case "${words[1]}" in
        analyze)
            if [[ "$cur" == -* ]]; then
                COMPREPLY+=(-h --help -v)
            fi
            COMPREPLY+=(mysql nginx sqlite)
            readarray -t COMPREPLY < <(compgen -W "${COMPREPLY[*]}" -- "$cur")
            ;;
        before-bench | bench)
            if [[ "$cur" == -* ]]; then
                COMPREPLY+=(-b --branch --pull -h --help -v)
            elif [ "$prev" == -b ] || [ "$prev" == --branch ]; then
                readarray -t BRANCHES < <(git -C "$REPO_DIR" branch --format='%(refname:short)')
                COMPREPLY+=("${BRANCHES[@]}")
            fi
            readarray -t COMPREPLY < <(compgen -W "${COMPREPLY[*]}" -- "$cur")
            ;;
        edit-command)
            if [[ "$cur" == -* ]]; then
                COMPREPLY+=(-h --help -v)
            else
                readarray -t COMMANDS < <(isutool help | cut -d' ' -f1)
                COMPREPLY+=("${COMMANDS[@]}")
            fi
            readarray -t COMPREPLY < <(compgen -W "${COMPREPLY[*]}" -- "$cur")
            ;;
        help) 
            if [[ "$cur" == -* ]]; then
                COMPREPLY+=(-h --help)
            else
                readarray -t COMMANDS < <(isutool help | cut -d' ' -f1)
                COMPREPLY+=("${COMMANDS[@]}")
            fi
            readarray -t COMPREPLY < <(compgen -W "${COMPREPLY[*]}" -- "$cur")
            ;;
        mysql)
            if [[ "$cur" == -* ]]; then
                COMPREPLY+=(-h --help)
            fi
            readarray -t COMPREPLY < <(compgen -W "${COMPREPLY[*]}" -- "$cur")
            ;;
        switch-branch)
            if [[ "$cur" == -* ]]; then
                COMPREPLY+=(-h --help -v)
            else
                readarray -t BRANCHES < <(git -C "$REPO_DIR" branch --format='%(refname:short)')
                COMPREPLY+=("${BRANCHES[@]}")
            fi
            readarray -t COMPREPLY < <(compgen -W "${COMPREPLY[*]}" -- "$cur")
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY+=(-h --help -v)
            fi
            readarray -t COMPREPLY < <(compgen -W "${COMPREPLY[*]}" -- "$cur")
            ;;
    esac
}

complete -F _isutool isutool
