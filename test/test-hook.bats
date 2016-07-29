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
  git commit --allow-empty -m "Initial commit"
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

@test "Can commit a normal file" {
  echo "Some content" > my_file
  git add my_file
  run git commit -m "Content"

  assert_success
  refute_line "my_file contains TODO"
}

@test "Commit a file containing a TODO fails if the user rejects the prompt" {
  echo "TODO - Add more content" > my_file
  git add my_file

  echo "n" > $FAKE_TTY
  run git commit -m "Commit with TODO"

  assert_failure
  assert_line "my_file contains TODO"
}

@test "Commit a file containing a TODO passes if the user accepts the prompt" {
  echo "TODO - Add more content" > my_file
  git add my_file

  echo "y" > $FAKE_TTY
  run git commit -m "Commit with TODO"

  assert_success
  assert_line "my_file contains TODO"
}
