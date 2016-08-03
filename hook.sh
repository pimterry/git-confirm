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
    local match_pattern=$2

    local file_changes_with_context=$(git diff -U999999999 -p --cached --color=always -- $file)

    # From the diff, get the green lines starting with '+' and including '$match_pattern'
    local matched_additions=$(echo "$file_changes_with_context" | grep -C4 $'^\e\\[32m\+.*'"$match_pattern")

    if [ -n "$matched_additions" ]; then
        echo -e "\n$file additions match '$match_pattern':\n"

        for matched_line in $matched_additions
        do
            echo "$matched_line"
        done

        if ask "Include this in your commit?"; then
            echo 'Including'
        else
            echo "Not committing, because $file matches $match_pattern"
            exit 1
        fi
    fi
}

# Actual hook logic:

MATCH=$(git config --get-all hooks.confirm.match)
if [ -z "$MATCH" ]; then
    echo "Git-Confirm: hooks.confirm.match not set, defaulting to 'TODO'"
    echo 'Add matches with `git config --add hooks.confirm.match "string-to-match"`'
    MATCH='TODO'
fi

for file in `git diff --cached -p --name-status | cut -c3-`; do
    for match_pattern in $MATCH
    do
        check_file $file $match_pattern
    done
done
exit
