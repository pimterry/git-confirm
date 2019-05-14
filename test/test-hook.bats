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
  cp "$BASE_DIR/hook.sh" ./.git/hooks/commit-msg
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

@test "Metatest" {
  echo "Some content" > my_file
  git add my_file
  # simulate git commit -m "add content"
  echo "add content" > .git/COMMIT_EDITMSG
  run ./.git/hooks/commit-msg .git/COMMIT_EDITMSG
  [ "$status" -eq 255 ]
}

@test "Should let you make normal all-good commits" {
  echo "Some content" > my_file
  git add my_file
  run git commit -m "Fix"
  assert_success
  refute_line --partial "This commit message does not conform our policy"
}


@test "Should not let messages not starting with capital letter" {
  specific_error_code=255

  echo "Some content" > my_file
  git add my_file
  # simulate git commit -m "add content"
  echo "add content" > .git/COMMIT_EDITMSG
  run ./.git/hooks/commit-msg .git/COMMIT_EDITMSG
  [ "$status" -eq "$specific_error_code" ] 

  echo "Some content" >> my_file && git add my_file
  # simulate git commit -m "add Content"
  echo "add content" > .git/COMMIT_EDITMSG
  run ./.git/hooks/commit-msg .git/COMMIT_EDITMSG
  [ "$status" -eq "$specific_error_code" ]    
  
  refute_line --partial "my_file additions match 'TODO'"
}


@test "Should not let messages not starting action verbs such as Add, Remove, Modify" {
  echo "Some content" > my_file
  git add my_file
  run git commit -m "Vary"
  echo "$status $spec_error_code"
  [ "$status" -eq 1 ]    

  echo "Some content" >> my_file && git add my_file
  run git commit -m "Burn"
  [ "$status" -eq 1 ]   

  echo "Some content" >> my_file && git add my_file
  run git commit -m "Download"
  [ "$status" -eq 1 ]    
  
  refute_line --partial "my_file additions match 'TODO'"
}

@test "Should not let messages with past tense" {
  specific_error_code=253

  echo "Some content" > my_file
  git add my_file
  # simulate git commit -m ...
  echo "Added content" > .git/COMMIT_EDITMSG
  run ./.git/hooks/commit-msg .git/COMMIT_EDITMSG
  [ "$status" -eq "$specific_error_code" ] 

  echo "Some content" >> my_file && git add my_file
  # simulate git commit -m ...
  echo "Fixed content" > .git/COMMIT_EDITMSG
  run ./.git/hooks/commit-msg .git/COMMIT_EDITMSG
  [ "$status" -eq "$specific_error_code" ]    
  
  refute_line --partial "my_file additions match 'TODO'"
}


@test "Should not be more than 50 characters" {
  specific_error_code=252

  echo "Some content" > my_file
  git add my_file
  # simulate git commit -m ...
  echo "Add here an overly verbose line that is longer than 50 characters" > .git/COMMIT_EDITMSG
  run ./.git/hooks/commit-msg .git/COMMIT_EDITMSG
  [ "$status" -eq "$specific_error_code" ] 
  
  refute_line --partial "my_file additions match 'TODO'"
}

@test "XP becomes less if mistake was made and more if good commit message detected" {
  initial_xp=100
  git config --add hooks.xp $initial_xp
  echo "Some content" > my_file
  git add my_file
  # simulate git commit -m ...
  run git commit -m "added feature"
  smaller_xp=$(git config --get hooks.xp) 
  echo "$smaller_xp < $initial_xp"
  [ "$smaller_xp" -lt "$initial_xp" ] 

  echo "Some content" >> my_file
  git add my_file
  # simulate git commit -m ...
  run git commit -m "Add new feature"
  bigger_xp=$(git config --get hooks.xp) 
  echo "$bigger_xp > $smaller_xp"
  [ "$bigger_xp" -gt "$smaller_xp" ]
  
  refute_line --partial "my_file additions match 'TODO'"
}