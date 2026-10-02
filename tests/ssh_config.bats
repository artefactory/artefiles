#!/usr/bin/env bats
# ~/.ssh/config is edited by hand, so chezmoi must never track or overwrite it.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

@test "no .ssh path is managed" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  ! chezmoi_managed "$H" | grep -E '^\.ssh(/|$)'
}

@test "apply does not create ~/.ssh/config" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_file_absent "$H/.ssh/config"
}

@test "apply leaves an existing ~/.ssh/config untouched" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  mkdir -p "$H/.ssh"
  printf 'Host mine\n  HostName example.com\n' > "$H/.ssh/config"
  before=$(cat "$H/.ssh/config")
  chezmoi_apply "$H"
  [ "$(cat "$H/.ssh/config")" = "$before" ]
}

@test ".chezmoiignore has no entry for the unmanaged ssh config" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(SSH_CLIENT="dummy 1 2" chezmoi_render "$H" .chezmoiignore)
  ! printf '%s\n' "$rendered" | grep -qF '.ssh/config'
}

@test "docs do not present ~/.ssh/config as chezmoi-managed" {
  if grep -nE '^~/\.ssh/config +# SSH configuration' "$REPO_ROOT/README.md" "$REPO_ROOT/CHEATSHEET.md"; then return 1; fi
  ! grep -nF 'chezmoi edit ~/.ssh/config' "$REPO_ROOT/README.md" "$REPO_ROOT/CHEATSHEET.md"
}
