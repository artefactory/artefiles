#!/usr/bin/env bats
# Verify .chezmoiignore module gates render correctly: per-module config
# directories materialize iff their module is selected. Acts as a contract
# test for the helper framework (does seed_chezmoi_config + apply actually
# round-trip the modules list?) and a regression check for the module
# system itself.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

@test "no modules: editor/terminal/atuin/aerospace dirs absent" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_file_absent "$H/.config/nvim"
  assert_file_absent "$H/.config/ghostty"
  assert_file_absent "$H/.config/atuin"
  assert_file_absent "$H/.config/aerospace"
}

@test "no modules: chezmoi managed lists no module dirs" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  managed=$(chezmoi_managed "$H")
  ! echo "$managed" | grep -qE '^\.config/(nvim|ghostty|atuin|aerospace)(/|$)'
}

@test "editor module: nvim dir is materialized" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/nvim"
}

@test "terminal module: ghostty dir is materialized" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["terminal"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/ghostty"
}

@test "atuin module: atuin dir is materialized" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["atuin"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/atuin"
}

@test "applying twice is idempotent (editor module)" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor"]}'
  chezmoi_apply "$H"
  assert_idempotent "$H"
}
