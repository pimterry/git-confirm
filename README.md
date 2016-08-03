# git-confirm
Git hook to catch placeholders and temporary changes (TODO / @ignore) before you commit them.

Git Confirm:

* Stops you ever accidentally committing bad temporary changes.
* Is interactive, checking each match with you so you can't miss it (and can still include it if you like).
* Only considers lines newly `add`ed and about to be committed, so no false positives.
* Includes (diff-colorized) context with each match
* Installs in any project with a single command
* Is configurable to match anything, through standard git config
* Is well tested. See [tests/\*.bats](https://github.com/pimterry/git-confirm/blob/master/test/test-hook.bats#L40-L9999).
* Works on Linux & OSX, with no dependencies (**maybe** Windows too, with compatible Bash. Testers and fixes welcome!)
* Doesn't break non-interactive environments (e.g. commands sent over SSH, some Git UIs).

## To Install
In the root of your Git repository, run:

```bash
curl https://cdn.rawgit.com/pimterry/git-confirm/v0.1.0/hook.sh > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

All done. If you want to check it's installed correctly you can run:

```bash
echo "TODO" > ./test-git-confirm
git add ./test-git-confirm

# Should prompt you to confirm added 'TODO'. Press 'n' to cancel commit.
git commit -m "Testing git confirm"
```

## To Configure

By default, git-confirm will catch and warn about lines including 'TODO' only.

If you want to match a different pattern, use:

```bash
git config --add hooks.confirm.match "TODO"
```
