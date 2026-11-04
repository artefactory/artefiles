#!/usr/bin/env bats
# VS Code Remote-SSH and Dev Containers with fish as the login shell.
# vscode_remote_fix sets the client setting remote.SSH.useLocalServer=false,
# which avoids the local-server handshake that fails with some fish hosts;
# nothing sets it by default. config.fish skips its interactive-only init
# while VS Code reads the environment (VSCODE_RESOLVING_ENVIRONMENT set);
# vscode_remote_check and the doctor time the probe VS Code runs.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
  if [[ "$(uname)" == "Darwin" ]]; then
    SETTINGS_REL="Library/Application Support/Code/User/settings.json"
  else
    SETTINGS_REL=".config/Code/User/settings.json"
  fi
}

FIX=dot_local/bin/executable_vscode_remote_fix
CHECK=dot_config/fish/functions/vscode_remote_check.fish
KEY='"remote.SSH.useLocalServer"'

# --- A: nothing is set by default ---------------------------------------------

@test "the settings file leaves remote.SSH.useLocalServer to VS Code's default" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"
  assert_valid_json "$H/$SETTINGS_REL"
  ! grep -q 'useLocalServer' "$H/$SETTINGS_REL"
}

@test "vscode_remote_fix is installed in ~/.local/bin with or without the vscode module" {
  for m in '[]' '["vscode"]'; do
    H=$(mk_fake_home "$BATS_TEST_TMPDIR/m$RANDOM")
    seed_chezmoi_config "$H" "{\"modules\":$m}"
    chezmoi_managed "$H" | grep -qxF .local/bin/vscode_remote_fix
  done
}

# --- B: vscode_remote_fix, run by hand on the VS Code machine -----------------

# run_fix [ARG...] — run the command with HOME=$H.
run_fix() {
  run env HOME="$H" sh "$REPO_ROOT/$FIX" "$@"
}

# settings CONTENT — write the VS Code user settings of this OS.
settings() {
  mkdir -p "$(dirname "$H/$SETTINGS_REL")"
  printf "$1" > "$H/$SETTINGS_REL"
}

@test "vscode_remote_fix inserts the key after the first { of a JSONC file and keeps the rest" {
  H=$(mk_fake_home)
  settings '// my settings\n{\n  // a comment\n  "editor.fontSize": 14,\n}\n'
  run_fix
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$H/$SETTINGS_REL")" = "{" ]
  [ "$(sed -n 3p "$H/$SETTINGS_REL")" = "  $KEY: false," ]
  [ "$(sed -n 1p "$H/$SETTINGS_REL")" = "// my settings" ]
  [ "$(sed -n '4,$p' "$H/$SETTINGS_REL")" = "$(printf '  // a comment\n  "editor.fontSize": 14,\n}')" ]
}

@test "vscode_remote_fix is idempotent: a second run changes nothing" {
  H=$(mk_fake_home)
  settings '{\n  "editor.fontSize": 14\n}\n'
  run_fix
  [ "$status" -eq 0 ]
  cp "$H/$SETTINGS_REL" "$BATS_TEST_TMPDIR/first"
  assert_valid_json "$H/$SETTINGS_REL"
  run_fix
  [ "$status" -eq 0 ]
  [[ "$output" == *"already false"* ]]
  cmp "$BATS_TEST_TMPDIR/first" "$H/$SETTINGS_REL"
  [ "$(grep -c "$KEY" "$H/$SETTINGS_REL")" -eq 1 ]
}

@test "vscode_remote_fix handles {} on one line" {
  H=$(mk_fake_home)
  settings '{}\n'
  run_fix
  [ "$status" -eq 0 ]
  [ "$(grep -c "$KEY: false" "$H/$SETTINGS_REL")" -eq 1 ]
  [ "$(tail -n 1 "$H/$SETTINGS_REL")" = "}" ]
}

@test "vscode_remote_fix switches a key set to true and keeps the rest of the line" {
  H=$(mk_fake_home)
  settings '{\n  "a": 1,\n  "remote.SSH.useLocalServer" : true, // mine\n  // "remote.SSH.useLocalServer": true,\n}\n'
  run_fix
  [ "$status" -eq 0 ]
  [ "$(sed -n 3p "$H/$SETTINGS_REL")" = "  $KEY: false, // mine" ]
  [ "$(sed -n 4p "$H/$SETTINGS_REL")" = '  // "remote.SSH.useLocalServer": true,' ]
  [ "$(grep -c "$KEY" "$H/$SETTINGS_REL")" -eq 2 ]
}

@test "a commented-out key does not count as present" {
  H=$(mk_fake_home)
  settings '{\n  // "remote.SSH.useLocalServer": false,\n  "a": 1\n}\n'
  run_fix
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$H/$SETTINGS_REL")" = "  $KEY: false," ]
}

@test "vscode_remote_fix creates the settings file when there is none" {
  H=$(mk_fake_home)
  run_fix
  [ "$status" -eq 0 ]
  assert_valid_json "$H/$SETTINGS_REL"
  assert_jq_key "$H/$SETTINGS_REL" '.["remote.SSH.useLocalServer"]' false
}

@test "vscode_remote_fix edits the settings file it is given" {
  H=$(mk_fake_home)
  printf '{\n}\n' > "$BATS_TEST_TMPDIR/insiders.json"
  run_fix "$BATS_TEST_TMPDIR/insiders.json"
  [ "$status" -eq 0 ]
  grep -qF "$KEY: false" "$BATS_TEST_TMPDIR/insiders.json"
  assert_file_absent "$H/$SETTINGS_REL"
}

@test "on Linux vscode_remote_fix edits ~/.config/Code/User/settings.json" {
  H=$(mk_fake_home)
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN" "$H/.config/Code/User"
  printf '#!/bin/sh\necho Linux\n' > "$BIN/uname"
  chmod +x "$BIN/uname"
  printf '{\n}\n' > "$H/.config/Code/User/settings.json"
  run env HOME="$H" PATH="$BIN:$PATH" sh "$REPO_ROOT/$FIX"
  [ "$status" -eq 0 ]
  grep -qF "$KEY: false" "$H/.config/Code/User/settings.json"
}

@test "vscode_remote_fix fails and names the setting on a file it cannot write" {
  [ "$(id -u)" -ne 0 ] || skip "root can write a read-only file"
  H=$(mk_fake_home)
  settings '{\n}\n'
  chmod a-w "$H/$SETTINGS_REL"
  run_fix
  chmod u+w "$H/$SETTINGS_REL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"remote.SSH.useLocalServer"* ]]
  ! grep -q useLocalServer "$H/$SETTINGS_REL"
}

@test "vscode_remote_fix passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck -s sh "$REPO_ROOT/$FIX"
}

# --- C: config.fish during VS Code's environment probe ------------------------

# fish_login [ENV...] — render config.fish as on Linux (no Homebrew PATH, so
# the stubs in ~/.local/bin win) with the atuin module, then start an
# interactive login fish that sources it and prints the environment it set.
# --no-config keeps the host's vendor conf.d (Homebrew's direnv hook) out.
# atuin, fzf and direnv are stubs that log each call to $MARK.
fish_login() {
  command -v fish > /dev/null || skip "fish is not installed"
  H=$(mk_fake_home)
  MARK="$BATS_TEST_TMPDIR/marks"
  mkdir -p "$H/.local/bin" "$H/.cargo/bin" "$H/.config/fish"
  for t in atuin fzf direnv; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\n' "$t" "$MARK" > "$H/.local/bin/$t"
    chmod +x "$H/.local/bin/$t"
  done
  seed_chezmoi_config "$H" '{"modules":["atuin"]}'
  XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < <(sed 's/eq \.chezmoi\.os "darwin"/false/' "$REPO_ROOT/dot_config/fish/config.fish.tmpl") \
    > "$H/.config/fish/config.fish"
  run env -i HOME="$H" PATH="$H/.local/bin:/usr/bin:/bin" "$@" "$(command -v fish)" --no-config "${FISH_FLAGS[@]}" \
    "source $H/.config/fish/config.fish; echo EDITOR=\$EDITOR; echo FZF=\$FZF_DEFAULT_OPTS; echo USER_PATHS=(string join : \$fish_user_paths)" < /dev/null
}

@test "during VS Code's probe, config.fish skips direnv, fzf and atuin and still sets the environment" {
  FISH_FLAGS=(-i -l -c)
  fish_login VSCODE_RESOLVING_ENVIRONMENT=1
  [ "$status" -eq 0 ]
  [ ! -s "$MARK" ]
  [[ "$output" == *"EDITOR=vi"* ]]
  [[ "$output" == *"FZF=--height"* ]]
  # fish_add_path fills fish_user_paths; fish's own startup, skipped by
  # --no-config, is what copies it into PATH.
  [[ "$output" == *"USER_PATHS="*"$H/.cargo/bin"* ]]
}

@test "an interactive login fish without the probe variable runs direnv, fzf and atuin" {
  FISH_FLAGS=(-i -l -c)
  fish_login
  [ "$status" -eq 0 ]
  grep -q '^direnv hook fish' "$MARK"
  grep -q '^fzf --fish' "$MARK"
  grep -q '^atuin init fish' "$MARK"
}

@test "a non-interactive fish still runs direnv, fzf and atuin as before" {
  FISH_FLAGS=(-c)
  fish_login
  [ "$status" -eq 0 ]
  grep -q '^direnv hook fish' "$MARK"
  grep -q '^fzf --fish' "$MARK"
  grep -q '^atuin init fish' "$MARK"
}

# --- D: vscode_remote_check -------------------------------------------------------

# fake_shell NAME BODY — an executable login shell that runs BODY, then the
# command VS Code passes after -ilc when VSCODE_RESOLVING_ENVIRONMENT=1.
fake_shell() {
  mkdir -p "$BATS_TEST_TMPDIR/shells/$1"
  FAKE="$BATS_TEST_TMPDIR/shells/$1/fish"
  printf '#!/bin/sh\n%s\n[ "$VSCODE_RESOLVING_ENVIRONMENT" = 1 ] && [ "$1" = -ilc ] && eval "$2"\n' "$2" > "$FAKE"
  chmod +x "$FAKE"
}

# check_fish [ENV...] — vscode_remote_check against $FAKE with a 2 s limit.
# 3>&- keeps a lingering child from holding bats' output open; it must not
# wrap `run` itself, which reports on that descriptor.
check_fish() {
  env -i HOME="$BATS_TEST_TMPDIR" PATH="/usr/bin:/bin" SHELL="$FAKE" VSCODE_REMOTE_CHECK_TIMEOUT=2 "$@" \
    "$(command -v fish)" --no-config -c "source $REPO_ROOT/$CHECK; vscode_remote_check" 3>&-
}

run_check() {
  command -v fish > /dev/null || skip "fish is not installed"
  run check_fish "$@"
}

@test "vscode_remote_check passes against a fast login shell and names vscode_remote_fix" {
  fake_shell fast ':'
  run_check TERM=xterm-256color
  [ "$status" -eq 0 ]
  [[ "$output" == *"$FAKE"* ]]
  [[ "$output" == *"vscode_remote_fix"* ]]
  [[ "$output" == *'"userEnvProbe": "loginInteractiveShell"'* ]]
  [[ "$output" != *"TERM"* ]]
}

@test "vscode_remote_check fails when the login shell is slower than the limit" {
  fake_shell slow 'sleep 4'
  run_check TERM=xterm-256color
  [ "$status" -eq 1 ]
  [[ "$output" == *"2 s"* ]]
}

@test "vscode_remote_check fails when a startup file reads stdin" {
  fake_shell reader 'read -r line'
  run_check TERM=xterm-256color
  [ "$status" -eq 1 ]
}

@test "vscode_remote_check fails when the login shell does not print the marker" {
  fake_shell mute 'exit 0'
  run_check TERM=xterm-256color
  [ "$status" -eq 1 ]
}

@test "vscode_remote_check warns when TERM is not set" {
  fake_shell fast ':'
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"TERM"* ]]
}

# --- E: docs ------------------------------------------------------------------

@test "the cheatsheet and the vscode reference name the setting, vscode_remote_check and vscode_remote_fix" {
  for doc in CHEATSHEET.md .claude/skills/artefiles/references/vscode.md; do
    grep -qF '"remote.SSH.useLocalServer": false' "$REPO_ROOT/$doc"
    grep -qF 'vscode_remote_check' "$REPO_ROOT/$doc"
    grep -qF 'vscode_remote_fix' "$REPO_ROOT/$doc"
  done
}
