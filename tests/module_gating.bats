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

@test "no modules: editor/terminal/atuin dirs absent" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_file_absent "$H/.config/nvim"
  assert_file_absent "$H/.config/ghostty"
  assert_file_absent "$H/.config/atuin"
}

@test "no modules: chezmoi managed lists no module dirs" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  managed=$(chezmoi_managed "$H")
  ! echo "$managed" | grep -qE '^\.config/(nvim|ghostty|atuin)(/|$)'
}

@test "editor module: nvim dir is materialized" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/nvim"
}

@test "ghostty module: ghostty dir is materialized" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["ghostty"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/ghostty"
}

@test "atuin module: atuin dir is materialized" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["atuin"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/atuin"
}

@test "review module gates the tuicr config dir" {
  H_off=$(mk_fake_home "$BATS_TEST_TMPDIR/tuicr-off")
  seed_chezmoi_config "$H_off" '{"modules":[]}'
  chezmoi_apply "$H_off"
  assert_file_absent "$H_off/.config/tuicr"

  H_on=$(mk_fake_home "$BATS_TEST_TMPDIR/tuicr-on")
  seed_chezmoi_config "$H_on" '{"modules":["review"]}'
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

@test "review module gates the linux tuicr install script" {
  [ "$(uname -s)" = Linux ] || skip "linux-only script"
  _assert_script_gating review .chezmoiscripts/linux/install-tuicr.sh
}

@test "python_dev module gates its install script" {
  _assert_script_gating python_dev .chezmoiscripts/zzzzz_install-python-tools.sh
}

@test "vscode module gates its linux install script" {
  [ "$(uname -s)" = Linux ] || skip "linux-only script"
  _assert_script_gating vscode .chezmoiscripts/linux/install-vscode.sh
}

@test "claude_code module gates its install script, on any OS" {
  _assert_script_gating claude_code .chezmoiscripts/install-claude-code.sh
}

@test "pi module gates its install script, on any OS" {
  _assert_script_gating pi .chezmoiscripts/install-pi.sh
}

# pikit_managed NAME DATA_JSON [no-email] — succeeds when the pi-kit script is
# managed under that config; no-email drops the email key from it. A failing
# chezmoi returns 2, so it never reads as "not managed".
pikit_managed() {
  local h managed
  h=$(mk_fake_home "$BATS_TEST_TMPDIR/pikit-$1")
  seed_chezmoi_config "$h" "$2"
  if [ "${3:-}" = no-email ]; then
    sed '/^email = /d' "$h/.config/chezmoi/chezmoi.toml" > "$h/no-email.toml"
    mv "$h/no-email.toml" "$h/.config/chezmoi/chezmoi.toml"
  fi
  managed=$(chezmoi_managed_with_scripts "$h") || return 2
  grep -qxF .chezmoiscripts/zzzzzz_install-pikit.sh <<< "$managed"
}

@test "the pi-kit script needs the pi and pi_kit modules and an @artefact.com email, in any case" {
  pikit_managed lower '{"modules":["pi","pi_kit"],"email":"jane.doe@artefact.com"}'
  pikit_managed upper '{"modules":["pi","pi_kit"],"email":"Jane.Doe@ARTEFACT.Com"}'
  local i=0 modules
  for modules in '[]' '["pi"]' '["pi_kit"]'; do
    i=$((i + 1))
    run pikit_managed "off-$i" "{\"modules\":$modules,\"email\":\"jane.doe@artefact.com\"}"
    [ "$status" -eq 1 ]
  done
}

@test "any other email, an empty one or none leaves the pi-kit script out" {
  local i=0 email
  for email in jane@example.com jane@notartefact.com jane@artefact.com.evil.io \
    jane@sub.artefact.com jane@artefactxcom @artefact.com jane@evil.io@artefact.com \
    artefact.com ""; do
    i=$((i + 1))
    run pikit_managed "other-$i" "$(jq -nc --arg e "$email" '{modules:["pi","pi_kit"],email:$e}')"
    [ "$status" -eq 1 ] || {
      echo "email '$email': status $status" >&2
      return 1
    }
  done
  run pikit_managed missing '{"modules":["pi","pi_kit"]}' no-email
  [ "$status" -eq 1 ]
}

@test "pi itself is installed whatever the email" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["pi"],"email":"jane@example.com"}'
  chezmoi_managed_with_scripts "$H" | grep -qxF .chezmoiscripts/install-pi.sh
}
