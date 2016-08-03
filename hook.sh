#!/bin/bash

# If we have a STDIN, use it, otherwise get one
if tty >/dev/null 2>&1; then
    TTY=$(tty)
else
    TTY=/dev/tty
fi

IFS=$'\n'

# http://djm.me/ask
ask() {
    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        # Read the answer
        read REPLY < "$TTY"

        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

check_file() {
    local file=$1
    local file_changes_with_context=$(git diff-index -U999999999 -p HEAD --cached --color=always -- $file)

    # From the diff, get the green lines starting with '+' and including 'TODO'
    local todo_additions=$(echo "$file_changes_with_context" | grep -C4 $'^\e\\[32m\+.*TODO')

    if [ -n "$todo_additions" ]; then
        echo -e "\n$file has new TODOs added:\n"

        for todo_line in $todo_additions
        do
            echo "$todo_line"
        done

        if ask "Include this in your commit?"; then
            echo 'Including'
        else
            echo "Not committing, because $file contains TODO"
            exit 1
        fi
    fi
}

# Actual hook logic:

MATCH=$(git config --get hooks.confirm.match)
if [ -z "$MATCH" ]; then
    echo "Git-Confirm: hooks.confirm.match not set, defaulting to 'TODO'"
    echo 'Add matches with `git config hooks.confirm.match --add "string-to-match"`'
    MATCH='TODO'
fi

for FILE in `git diff-index -p -M --name-status HEAD | cut -c3-`; do
    check_file $FILE
done
exit
