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
