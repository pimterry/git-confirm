# git-confirm
Git hook to catch placeholders and mistakes (TODO / @ignore) before you commit them

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
