#!/bin/sh

echo "Running hook"
for FILE in `git diff-index -p -M --name-status HEAD | cut -c3-`; do
    echo "Checking $FILE"
    grep 'TODO' $FILE 2>&1 >/dev/null
    if [ $? -eq 0 ]; then
        echo $FILE ' contains TODO'
        exit 1
    fi
done
exit
