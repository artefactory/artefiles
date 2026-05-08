#!/usr/bin/env bats
# Tests for the create_-prefixed VSCode settings.json shipped via chezmoi.
# Covers: file creation with expected keys, no-override semantics, idempotency.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
  if [[ "$(uname)" == "Darwin" ]]; then
    SETTINGS_REL="Library/Application Support/Code/User/settings.json"
  else
    SETTINGS_REL=".config/Code/User/settings.json"
  fi
}

@test "vscode settings: file created with expected keys" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/$SETTINGS_REL"
  assert_valid_json "$H/$SETTINGS_REL"
  assert_jq_key "$H/$SETTINGS_REL" '.["workbench.colorTheme"]' "Catppuccin Mocha"
  assert_jq_key "$H/$SETTINGS_REL" '.["editor.fontFamily"]' "'FiraCode Nerd Font Mono', monospace"
  assert_jq_key "$H/$SETTINGS_REL" '.["terminal.integrated.defaultProfile.linux"]' "fish"
}

@test "vscode settings: no-override semantics (create_ protects user edits)" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_no_override "$H" "$SETTINGS_REL" "my-custom-setting"
}

@test "vscode settings: applying twice is idempotent" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_idempotent "$H"
}
