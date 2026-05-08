#!/usr/bin/env bats
# Smoke test: hermetic helpers can seed a fake home and run chezmoi apply
# end-to-end without touching the real environment.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

@test "helpers source cleanly and REPO_ROOT resolves" {
  [ -n "$REPO_ROOT" ]
  [ -f "$REPO_ROOT/.chezmoi.toml.tmpl" ]
}

@test "seed_chezmoi_config writes a parseable config" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  assert_file_exists "$H/.config/chezmoi/chezmoi.toml"
  grep -q 'sourceDir' "$H/.config/chezmoi/chezmoi.toml"
}

@test "chezmoi apply succeeds with no modules and is idempotent" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_idempotent "$H"
}
