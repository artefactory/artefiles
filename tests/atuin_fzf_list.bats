#!/usr/bin/env bats
# The picker loads the list once and fzf filters it, so the list script caps the rows.

@test "the list script caps the rows atuin returns, 5000 by default" {
  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/args"\n' "$BATS_TEST_TMPDIR" > "$bin/atuin"
  chmod +x "$bin/atuin"
  script="$REPO_ROOT/dot_config/fish/scripts/executable_atuin_fzf_list.sh"
  PATH="$bin:$PATH" bash "$script" "q" global
  [ "$(grep -x -A1 -- '--limit' "$BATS_TEST_TMPDIR/args" | tail -1)" = "5000" ]
  PATH="$bin:$PATH" ATUIN_FZF_LIMIT=50 bash "$script" "q" global
  [ "$(grep -x -A1 -- '--limit' "$BATS_TEST_TMPDIR/args" | tail -1)" = "50" ]
}

@test "the picker loads the list once and lets fzf filter it" {
  f="$BATS_TEST_DIRNAME/../dot_config/fish/functions/__atuin_fzf_search.fish"
  grep -q 'start:reload' "$f"
  if grep -qE -- '--disabled|change:reload' "$f"; then return 1; fi
}
