#!/usr/bin/env bats
# install.sh runs the module checklist before `chezmoi init` and stores the
# answer in the chezmoi config, so chezmoi does not prompt for modules again.
# Everything it could install or change is stubbed.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/chezmoi.calls"
  SEEN="$BATS_TEST_TMPDIR/config.seen"
  ANSWERS="$BATS_TEST_TMPDIR/answers"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"

  # chezmoi records its arguments and the config it finds when init runs.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
echo "\$*" >> "$CALLS"
case "\$1" in
  init) cp "$H/.config/chezmoi/chezmoi.toml" "$SEEN" 2> /dev/null || : ;;
  source-path) exit 1 ;;
esac
exit 0
STUB
  # gh is logged in; "repo clone" copies the files the checklist needs.
  cat > "$BIN/gh" << STUB
#!/bin/sh
echo "gh \$*" >> "$CALLS"
if [ "\$1 \$2" = "repo clone" ]; then
  mkdir -p "\$4"
  cp "$REPO_ROOT/select-modules.sh" "$REPO_ROOT/.chezmoi.toml.tmpl" "\$4/"
fi
exit 0
STUB
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

idx() { prompt_module_names | grep -nx "$1" | cut -d: -f1; }

# run_install [VAR=VALUE ...] — run install.sh from the checkout with the stubs.
run_install() {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" "$@" sh "$REPO_ROOT/install.sh" --destination "$H/dest"
}

# run_quick_start [VAR=VALUE ...] — run install.sh the way the Quick Start does:
# its text through `sh -c`, with no checkout around it.
run_quick_start() {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" "$@" sh -c "$(cat "$REPO_ROOT/install.sh")"
}

answers() { : > "$ANSWERS"; for l in "$@"; do printf '%s\n' "$l" >> "$ANSWERS"; done; }

@test "the checklist runs before chezmoi init and its choice is stored as bare names" {
  answers "$(idx editor)" "$(idx atuin)" "" y
  run_install ARTEFILES_SELECT_TTY="$ANSWERS"
  [ "$status" -eq 0 ]
  [ -f "$SEEN" ]
  grep -qF 'modules = ["editor","atuin"]' "$SEEN"
  grep -q '^init --apply --source=' "$CALLS"
}

@test "an existing chezmoi config skips the checklist" {
  printf '[data]\n  modules = ["prek"]\n' > "$H/.config/chezmoi/chezmoi.toml"
  answers "$(idx editor)" "" y
  run_install ARTEFILES_SELECT_TTY="$ANSWERS"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Select the optional modules"* ]]
  grep -qF 'modules = ["prek"]' "$SEEN"
}

@test "without a terminal nothing is asked and chezmoi keeps its own prompt" {
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Select the optional modules"* ]]
  [ ! -f "$SEEN" ]
  grep -q '^init --apply' "$CALLS"
}

@test "CI never gets the checklist" {
  answers "$(idx editor)" "" y
  run_install CI=true
  [ "$status" -eq 0 ]
  [[ "$output" != *"Select the optional modules"* ]]
  [ ! -f "$SEEN" ]
}

@test "a cancelled selection stops the install before chezmoi init" {
  answers "$(idx editor)"
  run_install ARTEFILES_SELECT_TTY="$ANSWERS"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Installation cancelled"* ]]
  if grep -q '^init' "$CALLS"; then return 1; fi
}

@test "dry-run never shows the checklist" {
  answers "$(idx editor)" "" y
  run env -u CI HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" ARTEFILES_SELECT_TTY="$ANSWERS" \
    sh "$REPO_ROOT/install.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"Select the optional modules"* ]]
}

@test "the Quick Start path clones the repo with gh so the checklist exists" {
  answers "$(idx cmux)" "" y
  run_quick_start ARTEFILES_SELECT_TTY="$ANSWERS"
  [ "$status" -eq 0 ]
  grep -q "^gh repo clone artefactory/artefiles $H/.local/share/chezmoi" "$CALLS"
  grep -q "^init --apply --source=$H/.local/share/chezmoi" "$CALLS"
  grep -qF 'modules = ["cmux"]' "$SEEN"
}

@test "the Quick Start path without a terminal keeps asking chezmoi to clone" {
  run_quick_start
  [ "$status" -eq 0 ]
  grep -q '^init --apply artefactory/artefiles' "$CALLS"
  if grep -q '^gh repo clone' "$CALLS"; then return 1; fi
}
