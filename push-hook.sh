#!/usr/bin/env bash

# If we have a STDIN, use it, otherwise get one
if tty >/dev/null 2>&1; then
    TTY=$(tty)
else
    TTY=/dev/tty
fi

IFS=$'\n'

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

ZERO="0000000000000000000000000000000000000000"

MATCH=$(git config --get-all hooks.confirm-push.match)
if [ -z "$MATCH" ]; then
    MATCH=$'^WIP\n^fixup\n^squash'
fi

PROTECTED=$(git config --get-all hooks.confirm-push.protected-branch)

while IFS=' ' read local_ref local_sha remote_ref remote_sha; do
    # Skip deletions
    if [ "$local_sha" = "$ZERO" ]; then
        continue
    fi

    # If protected branches are configured, skip unprotected branches (tags always checked)
    if [ -n "$PROTECTED" ]; then
        case "$local_ref" in
            refs/tags/*) ;; # always check tags
            *)
                branch_name="${local_ref#refs/heads/}"
                skip=true
                for protected in $PROTECTED; do
                    if [ "$branch_name" = "$protected" ]; then
                        skip=false
                        break
                    fi
                done
                if [ "$skip" = "true" ]; then
                    continue
                fi
                ;;
        esac
    fi

    # Determine the commit range to check
    if [ "$remote_sha" = "$ZERO" ]; then
        # New ref: check commits not reachable from any remote branch
        range_args=("$local_sha" "--not" "--remotes")
    else
        range_args=("$remote_sha..$local_sha")
    fi

    for match_pattern in $MATCH; do
        matched_commits=$(git log --format="%h %s" --grep="$match_pattern" -i "${range_args[@]}")

        if [ -n "$matched_commits" ]; then
            echo -e "\nCommit messages matching '$match_pattern':\n"

            for commit_line in $matched_commits; do
                echo "  $commit_line"
            done

            echo ""

            if ask "Push these commits?"; then
                echo 'Pushing'
            else
                echo "Push rejected: commits match '$match_pattern'"
                exit 1
            fi
        fi
    done
done

exit 0
