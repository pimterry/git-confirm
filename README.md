# git-confirm [![Travis Build Status](https://img.shields.io/travis/pimterry/git-confirm.svg)](https://travis-ci.org/pimterry/git-confirm)
Git hook to catch placeholders and temporary changes (TODO / @ignore) before you commit them.

[![Asciicast DEMO](asciicast.gif)](https://asciinema.org/a/dc7dr433caze9f8p65bitqs77?speed=2&autoplay=1)

Git Confirm:

* Stops you ever accidentally committing bad temporary changes.
* Is interactive, checking each match with you so you can't miss it (and can still include it if you like).
* Only considers lines newly `add`ed and about to be committed, so no false positives.
* Includes (diff-colorized) context with each match
* Installs in any project with a single command
* Is configurable to match any number of strings, through standard git config
* Is well tested. See [tests/test-hook.bats](https://github.com/pimterry/git-confirm/blob/master/test/test-hook.bats#L40-L9999).
* Works on Linux & OSX, with no dependencies (*maybe* Windows too, with compatible Bash. Testers and fixes welcome!)

## To Install
In the root of your Git repository, run:

```bash
curl https://cdn.rawgit.com/pimterry/git-confirm/v0.2.1/hook.sh > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```
(*Note the version number*)

All done. If you want to check it's installed correctly you can run:

```bash
echo "TODO" > ./test-git-confirm
git add ./test-git-confirm

# Should prompt you to confirm added 'TODO'. Press 'n' to cancel commit.
git commit -m "Testing git confirm"
```

*If you're security conscious, you may be reasonably suspicious of
[curling executable files](https://www.seancassidy.me/dont-pipe-to-your-shell.html).
Here you're on HTTPS throughout though, and you're not piping directly to execution so you can
check contents and the hash (against MD5 04baf1f87974681a92ee7fe8c0aa3aaa for v0.2.1) before using this, if you like.*

## To Configure

By default, git-confirm will catch and warn about lines including 'TODO' only.

If you want to match a different pattern, you can override this default and set your own patterns:

```bash
git config --add hooks.confirm.match "TODO"
```

Matches are passed verbatim to your local `grep`, and are treated as regular expressions. Note that all matches are case-sensitive.

You can repeatedly add patterns, and each of them will be matched in turn. To get, remove or totally
clear your config, use the standard [Git Config](https://git-scm.com/docs/git-config) commands:

```bash
git config --get-all hooks.confirm.match
git config --unset hooks.confirm.match 'TODO'
git config --unset-all hooks.confirm.match
```

## Contributing
Want to file a bug? That's great! Please search issues first though to check it hasn't already been filed, and provide as much information as you can (your OS, terminal and Git-Confirm version as a minimum).

Want to help improve Git-Confirm?

* Check out the project:
  `git clone --recursive https://github.com/pimterry/git-confirm.git`

  (Note 'recursive' - this ensures submodules are included)
* Check the tests pass locally: `./test.sh`
* Add tests for your change in test/test-hook.bats

  Check out the [BATS](https://github.com/sstephenson/bats) documentation if you're not familiar with it, or just crib from the existing tests.
* Add any documentation required to this README.
* Commit and push your changes
* Open a PR!

Need any ideas? Take a look at the Git Confirm [Huboard](https://huboard.com/pimterry/git-confirm#/) to quickly see the next features to look at.

## Release process

* Make changes
* Update Curl version number and hash (`md5 ./hook.sh`) in README.
* Commit everything
* Tag with new version numbers (`git tag vX.Y.Z`)
* Push including tags (`git push origin --tags`)
