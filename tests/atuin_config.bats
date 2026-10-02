#!/usr/bin/env bats
# Atuin search scope: both the up-arrow and Ctrl+R search the global history.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

@test "up-arrow searches the global history" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["atuin"]}'
  chezmoi_apply "$H"

  grep -qE '^filter_mode_shell_up_key_binding = "global"' "$H/.config/atuin/config.toml"
}

@test "Ctrl+R keeps the global filter and workspace detection" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["atuin"]}'
  chezmoi_apply "$H"

  grep -qE '^filter_mode = "global"' "$H/.config/atuin/config.toml"
  grep -qE '^workspaces = true' "$H/.config/atuin/config.toml"
}
