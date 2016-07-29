#!/bin/bash

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

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read REPLY </dev/tty

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

for FILE in `git diff-index -p -M --name-status HEAD | cut -c3-`; do
    grep 'TODO' $FILE 2>&1 >/dev/null
    if [ $? -eq 0 ]; then
        echo "$FILE includes TODO"
	if ask "Include this in your commit?"; then
            echo 'Including'
	else
            echo "Not committing, because $FILE contains TODO"
            exit 1
        fi
    fi
done
exit
