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

  # Isolate from user/system git config
  export HOME=$TMP_DIRECTORY

  # Set up a bare remote repo
  git init --bare "$TMP_DIRECTORY/remote.git"

  # Clone it to get a local repo
  git clone "$TMP_DIRECTORY/remote.git" "$TMP_DIRECTORY/local"
  cd "$TMP_DIRECTORY/local"
  git config user.email "test@git-confirm"
  git config user.name "Git Confirm Tests"

  # Install the pre-push hook
  cp "$BASE_DIR/push-hook.sh" ./.git/hooks/pre-push

  # Make an initial commit and push to establish a baseline
  echo "initial" > initial_file
  git add initial_file
  git commit -m "Initial commit"
  DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$DEFAULT_BRANCH"
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

@test "Should allow pushing clean commits" {
  echo "clean content" > clean_file
  git add clean_file
  git commit -m "A perfectly clean commit"

  run git push origin "$DEFAULT_BRANCH"

  assert_success
}

@test "Should reject push with WIP commit when user declines" {
  echo "wip content" > wip_file
  git add wip_file
  git commit -m "WIP hacking on feature"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "Commit messages matching '^WIP'"
  assert_line --partial "WIP hacking on feature"
}

@test "Should allow push with WIP commit when user accepts" {
  echo "wip content" > wip_file
  git add wip_file
  git commit -m "WIP hacking on feature"

  echo "y" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_success
  assert_line --partial "Commit messages matching '^WIP'"
  assert_line --partial "WIP hacking on feature"
}

@test "Should catch fixup commits" {
  echo "fixup content" > fixup_file
  git add fixup_file
  git commit -m "fixup Initial commit"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "Commit messages matching '^fixup'"
  assert_line --partial "fixup Initial commit"
}

@test "Should catch squash commits" {
  echo "squash content" > squash_file
  git add squash_file
  git commit -m "squash Initial commit"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "Commit messages matching '^squash'"
  assert_line --partial "squash Initial commit"
}

@test "Should check all commits in push range" {
  echo "clean" > clean_file
  git add clean_file
  git commit -m "A clean commit"

  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP not ready yet"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "WIP not ready yet"
}

@test "Should only check new commits, not ones already on the remote" {
  # Push a WIP commit (bypassing hook)
  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP already pushed"
  git push origin "$DEFAULT_BRANCH" --no-verify

  # Now make a clean commit
  echo "clean" > clean_file
  git add clean_file
  git commit -m "A clean commit"

  run git push origin "$DEFAULT_BRANCH"

  assert_success
}

@test "Should handle new branch push correctly" {
  git checkout -b feature-branch

  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP on feature branch"

  echo "n" > $FAKE_TTY
  run git push origin feature-branch

  assert_failure
  assert_line --partial "WIP on feature branch"
}

@test "Should use custom patterns from hooks.confirm-push.match" {
  git config --add hooks.confirm-push.match "DONOTPUSH"

  echo "bad content" > bad_file
  git add bad_file
  git commit -m "DONOTPUSH secret stuff"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "Commit messages matching 'DONOTPUSH'"
}

@test "Should not match default patterns when custom patterns are set" {
  git config --add hooks.confirm-push.match "DONOTPUSH"

  echo "wip content" > wip_file
  git add wip_file
  git commit -m "WIP this should not trigger"

  run git push origin "$DEFAULT_BRANCH"

  assert_success
}

@test "Should support multiple configured patterns" {
  git config --add hooks.confirm-push.match "DONOTPUSH"
  git config --add hooks.confirm-push.match "SECRET"

  echo "bad content" > bad_file
  git add bad_file
  git commit -m "DONOTPUSH SECRET stuff"

  echo "y" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_success
  assert_line --partial "Commit messages matching 'DONOTPUSH'"
  assert_line --partial "Commit messages matching 'SECRET'"
}

@test "Should support regex patterns" {
  git config --add hooks.confirm-push.match "^WIP.*feature"

  echo "content" > my_file
  git add my_file
  git commit -m "WIP working on feature"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "Commit messages matching '^WIP.*feature'"
}

@test "Should display abbreviated commit hash and subject in prompt" {
  echo "wip content" > wip_file
  git add wip_file
  git commit -m "WIP hacking on feature"

  local short_hash=$(git log -1 --format="%h")

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "$short_hash WIP hacking on feature"
}

@test "Should not interfere with hooks.confirm.match (pre-commit config)" {
  git config --add hooks.confirm.match "FIXME"

  echo "clean content" > clean_file
  git add clean_file
  git commit -m "WIP commit with pre-commit config set" --no-verify

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "Commit messages matching '^WIP'"
}

@test "Should match case-insensitively" {
  echo "content" > my_file
  git add my_file
  git commit -m "wip lowercase feature"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "wip lowercase feature"
}

@test "Should match mixed case" {
  echo "content" > my_file
  git add my_file
  git commit -m "Wip mixed case feature"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "Wip mixed case feature"
}

@test "Should only show subject line for multi-line commit messages" {
  echo "content" > my_file
  git add my_file
  git commit -m "WIP short subject" -m "This is a long body paragraph that should not appear in the hook output"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "WIP short subject"
  refute_line --partial "long body paragraph"
}

@test "Should check all branches by default" {
  git checkout -b feature-branch

  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP on feature"

  echo "n" > $FAKE_TTY
  run git push origin feature-branch

  assert_failure
  assert_line --partial "WIP on feature"
}

@test "Should skip unprotected branches when protected-branch is set" {
  git config --add hooks.confirm-push.protected-branch "$DEFAULT_BRANCH"

  git checkout -b feature-branch
  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP on feature"

  run git push origin feature-branch

  assert_success
}

@test "Should still check protected branches" {
  git config --add hooks.confirm-push.protected-branch "$DEFAULT_BRANCH"

  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP on default branch"

  echo "n" > $FAKE_TTY
  run git push origin "$DEFAULT_BRANCH"

  assert_failure
  assert_line --partial "WIP on default branch"
}

@test "Should support multiple protected branches" {
  git config --add hooks.confirm-push.protected-branch "$DEFAULT_BRANCH"
  git config --add hooks.confirm-push.protected-branch "release"

  git checkout -b release
  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP on release"

  echo "n" > $FAKE_TTY
  run git push origin release

  assert_failure
  assert_line --partial "WIP on release"
}

@test "Should always check tags even when protected-branch is set" {
  git config --add hooks.confirm-push.protected-branch "$DEFAULT_BRANCH"

  # Create a WIP commit on a local-only branch (not pushed)
  git checkout -b local-only-branch
  echo "wip" > wip_file
  git add wip_file
  git commit -m "WIP tagged commit"

  # Tag that commit and push just the tag (not the branch)
  git tag v0.0.1-wip

  echo "n" > $FAKE_TTY
  run git push origin v0.0.1-wip

  assert_failure
  assert_line --partial "WIP tagged commit"
}
