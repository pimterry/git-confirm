# git-confirm
Git hook to catch placeholders and mistakes (TODO / @ignore) before you commit them

## To Install
In the root of your Git repository, run:

```bash
curl https://cdn.rawgit.com/pimterry/git-confirm/v0.1.0/hook.sh > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## To Configure

By default, git-confirm will catch and warn about lines including 'TODO' only.

If you want to match a specific pattern, use:

```bash
git config --add hooks.confirm.match "TODO"
```
