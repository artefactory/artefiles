#!/usr/bin/env bats

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

@test "shellcheck passes" {
  shellcheck "$REPO_ROOT/install.sh"
}

@test "--dry-run does not mutate destination" {
  H="$BATS_TEST_TMPDIR/h"
  "$REPO_ROOT/install.sh" --destination "$H" --dry-run
  [ -z "$(ls -A "$H" 2> /dev/null)" ]
}

@test "order: brew install logged before chezmoi init" {
  [ "$(uname)" = "Darwin" ] || skip "darwin only"
  command -v brew > /dev/null 2>&1 && skip "brew already installed"
  out=$("$REPO_ROOT/install.sh" --dry-run 2>&1)
  printf '%s\n' "$out" | awk '/Installing Homebrew/{b=NR} /Running .chezmoi/{c=NR} END{exit !(b && c && b<c)}'
}

# Quick Start runs `sh -c "$(curl … install.sh)"`: no script file exists, so
# $0 is "sh" and the script's own dirname is /bin, not a checkout.
@test "sh -c invocation: chezmoi clones the repo, no --source" {
  cd "$BATS_TEST_TMPDIR"
  run sh -c "$(cat "$REPO_ROOT/install.sh")" sh --destination "$BATS_TEST_TMPDIR/h" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running 'chezmoi init --apply artefactory/artefiles"* ]]
  [[ "$output" != *"--source="* ]]
}

@test "checkout invocation: --source is the checkout" {
  root="$(cd "$REPO_ROOT" && pwd -P)"
  cd "$BATS_TEST_TMPDIR"
  run "$REPO_ROOT/install.sh" --destination "$BATS_TEST_TMPDIR/h" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running 'chezmoi init --apply --source=${root} "* ]]
}
