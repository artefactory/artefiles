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

@test "git_advanced module gates the tuicr config dir" {
  H_off=$(mk_fake_home "$BATS_TEST_TMPDIR/tuicr-off")
  seed_chezmoi_config "$H_off" '{"modules":[]}'
  chezmoi_apply "$H_off"
  assert_file_absent "$H_off/.config/tuicr"

  H_on=$(mk_fake_home "$BATS_TEST_TMPDIR/tuicr-on")
  seed_chezmoi_config "$H_on" '{"modules":["git_advanced"]}'
  chezmoi_apply "$H_on"
  assert_file_exists "$H_on/.config/tuicr"
}

@test "applying twice is idempotent (editor module)" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor"]}'
  chezmoi_apply "$H"
  assert_idempotent "$H"
}

# Per-module install-script gating: each module's linux install script must be
# managed iff the module is selected. Skipped on non-linux since the OS branch
# in .chezmoiignore excludes .chezmoiscripts/linux/** unconditionally there.
_assert_script_gating() {
  local module="$1" script="$2"

  H_off=$(mk_fake_home "$BATS_TEST_TMPDIR/off-$module")
  seed_chezmoi_config "$H_off" '{"modules":[]}'
  if chezmoi_managed_with_scripts "$H_off" | grep -qxF "$script"; then
    echo "$script managed when module '$module' disabled" >&2
    return 1
  fi

  H_on=$(mk_fake_home "$BATS_TEST_TMPDIR/on-$module")
  seed_chezmoi_config "$H_on" "$(jq -nc --arg m "$module" '{modules:[$m]}')"
  if ! chezmoi_managed_with_scripts "$H_on" | grep -qxF "$script"; then
    echo "$script not managed when module '$module' enabled" >&2
    return 1
  fi
}

@test "gcloud module gates its linux install script" {
  [ "$(uname -s)" = Linux ] || skip "linux-only script"
  _assert_script_gating gcloud .chezmoiscripts/linux/install-gcloud.sh
}

@test "git_advanced module gates its linux install script" {
  [ "$(uname -s)" = Linux ] || skip "linux-only script"
  _assert_script_gating git_advanced .chezmoiscripts/linux/install-git-extras.sh
}

@test "git_advanced module gates the linux tuicr install script" {
  [ "$(uname -s)" = Linux ] || skip "linux-only script"
  _assert_script_gating git_advanced .chezmoiscripts/linux/install-tuicr.sh
}

@test "onepassword module gates its linux install script" {
  [ "$(uname -s)" = Linux ] || skip "linux-only script"
  _assert_script_gating onepassword .chezmoiscripts/linux/install-1password-cli.sh
}

@test "python_dev module gates its install script" {
  _assert_script_gating python_dev .chezmoiscripts/zzzzz_install-python-tools.sh
}

@test "agent_skills module gates its install script" {
  _assert_script_gating agent_skills .chezmoiscripts/install-agent-skills.sh
}
