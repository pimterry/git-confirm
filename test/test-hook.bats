#!./libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# Set up stubs for faking TTY input
export FAKE_TTY="$BATS_TMPDIR/fake_tty"
function tty() { echo $FAKE_TTY; }
export -f tty

# Remember where the hook is
BASE_DIR=$(dirname $BATS_TEST_DIRNAME)
# Set up a directory for our git repo
TMP_DIRECTORY=$(mktemp -d)

setup() {
  # Clear initial TTY input
  echo "" > $FAKE_TTY

  # Set up a git repo
  cd $TMP_DIRECTORY
  git init
  git config user.email "test@git-confirm"
  git config user.name "Git Confirm Tests"
  cp "$BASE_DIR/hook.sh" ./.git/hooks/pre-commit
}

teardown() {
  if [ $BATS_TEST_COMPLETED ]; then
    echo "Deleting $TMP_DIRECTORY"
    rm -rf $TMP_DIRECTORY
  else
    echo "** Did not delete $TMP_DIRECTORY, as test failed **"
  fi

  cd $BATS_TEST_DIRNAME
}

@test "Should let you make normal all-good commits" {
  echo "Some content" > my_file
  git add my_file
  run git commit -m "Content"

  assert_success
  refute_line --partial "my_file additions match 'TODO'"
}

@test "Should reject commits containing a TODO if the user rejects the prompt" {
  echo "TODO - Add more content" > my_file
  git add my_file

  echo "n" > $FAKE_TTY
  run git commit -m "Commit with TODO"

  assert_failure
  assert_line --partial "my_file additions match 'TODO'"
}

@test "Should accept commits containing a TODO if the user accepts the prompt" {
  echo "TODO - Add more content" > my_file
  git add my_file

  echo "y" > $FAKE_TTY
  run git commit -m "Commit with TODO"

  assert_success
  assert_line --partial "my_file additions match 'TODO'"
}

@test "Should includes changed line numbers in message" {
  skip # TODO - Disabled, whilst broken by move to git diffing.

  cat << EOF > file_to_commit
start
TODO
end
EOF
  git add file_to_commit

  echo "y" > $FAKE_TTY
  run git commit -m "Commit with TODO"

  assert_success
  assert_line --partial "2:TODO"
}

@test "Should includes only the changed line + context in message" {
  cat << EOF > file_to_commit
File start
.
.
.
.
.
.
.
line before
TODO - add things
line after
EOF
  git add file_to_commit

  echo "y" > $FAKE_TTY
  run git commit -m "Commit with TODO"

  refute_line --partial "File start"
  assert_line --partial "line before"
  assert_line --partial "TODO - add things"
  assert_line --partial "line after"
}

@test "Doesn't warn for all-good changes to files that already have a TODO" {
  echo "TODO" > my_file
  echo "More Content" >> my_file
  git add my_file
  git commit -m "Commit with a TODO" --no-verify

  echo "More all-good content" >> my_file
  git add my_file

  run git commit -m "Commit with no new TODOs"
  assert_success
}

@test "Doesn't warn for changes that haven't been added to the commit" {
  echo "Content to commit" > my_file
  git add my_file

  echo "Content un-added, with TODO" >> my_file

  run git commit -m "Commit with TODO un-added"
  assert_success
}

@test "Complains if hooks.confirm.match is not set" {
  run git commit --allow-empty -m "Empty commit"

  assert_success
  assert_line --partial "hooks.confirm.match not set"
}

@test "Doesn't complain if hooks.confirm.match is set" {
  git config --add hooks.confirm.match "FIXME"
  run git commit --allow-empty -m "Empty commit"

  assert_success
  refute_line --partial "hooks.confirm.match not set"
}

@test "Uses different match from hooks.confirm.match if set" {
  git config --add hooks.confirm.match "FIXME"

  echo "FIXME" > my_file
  git add my_file
  echo "n" > $FAKE_TTY
  run git commit --allow-empty -m "Commit including fix me"

  assert_failure
  assert_line --partial "my_file additions match 'FIXME'"
}

@test "Matches against multiple configured matchers" {
  git config --add hooks.confirm.match "FIXME"
  git config --add hooks.confirm.match "@ignore"

  echo "FIXME" > fixme_file
  echo "@ignore" > ignored_test_file
  git add fixme_file ignored_test_file

  echo "y" > $FAKE_TTY
  run git commit -m "Add two bad matches"

  assert_line --partial "fixme_file additions match 'FIXME'"
  assert_line --partial "ignored_test_file additions match '@ignore'"
}

@test "Support regex matches" {
  git config --add hooks.confirm.match "hello.*world"

  echo "hello crazy world" > my_code
  git add my_code

  echo "n" > $FAKE_TTY
  run git commit -m "Commit code matching regex"

  assert_failure
  assert_line --partial "my_code additions match 'hello.*world'"
}
