#!/usr/bin/env bats
# Regression guard for .chezmoiignore patterns.
#
# chezmoi matches .chezmoiignore patterns against TARGET paths (after stripping
# dot_/private_/.tmpl prefixes), not source paths. Writing "dot_config/nvim/**"
# silently never matches anything — the bug that motivated the move to
# target-style ".config/nvim/**". This test fails if anyone reintroduces
# source-style prefixes in .chezmoiignore patterns.

setup() {
  load 'helpers/setup'
}

@test ".chezmoiignore uses target paths (no dot_/ private_/ .tmpl in patterns)" {
  # Render the template (so we lint what chezmoi actually sees), then drop
  # blank lines and comments. Pattern lines must not start with dot_ or
  # private_, and must not end with .tmpl — those are source-state markers.
  # Empty modules list so every "if not (has ...)" ignore block renders —
  # otherwise selecting a module hides its (potentially buggy) pattern.
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(SSH_CLIENT="dummy 1 2" chezmoi_render "$H" .chezmoiignore)

  # Strip comments + blank lines, then look for source-state markers
  # anywhere in the pattern (not just at the start) — chezmoi strips
  # dot_/private_ prefixes and .tmpl suffixes wherever they appear, so any
  # such marker in a target-style pattern is a bug.
  patterns=$(printf '%s\n' "$rendered" \
    | sed 's/[[:space:]]*#.*$//' \
    | grep -v '^[[:space:]]*$' || true)

  bad=$(echo "$patterns" | grep -E '(dot_|private_|\.tmpl)' || true)
  if [ -n "$bad" ]; then
    printf 'source-state marker in .chezmoiignore pattern (must be target path):\n%s\n' "$bad" >&2
    return 1
  fi
}
