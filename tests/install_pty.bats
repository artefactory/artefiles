#!/usr/bin/env bats
# The module checklist reads single keys in raw terminal mode, a path that a file
# standing in for the terminal never reaches. These tests run the real install.sh
# in a pseudo-terminal and press keys, so the arrows, the redraw and the
# restoration of the terminal are checked as a person would meet them.
# Everything install.sh could change is stubbed.

setup() {
  command -v python3 > /dev/null 2>&1 || skip "python3 not available"
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  printf '#!/bin/sh\necho "chezmoi $*" >> "%s"\ncase "$1" in source-path) exit 1 ;; esac\nexit 0\n' "$CALLS" > "$BIN/chezmoi"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/gh"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sudo"
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# in_terminal STEPS_JSON — run install.sh in a pseudo-terminal answering STEPS_JSON
# (see helpers/pty_run.py), then print INSTALL_EXIT and the terminal settings, so
# a terminal left in raw mode shows. The wrapper survives ^C so it can report.
in_terminal() {
  run python3 "$REPO_ROOT/tests/helpers/pty_run.py" "$1" \
    env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SUDO_REFRESH=1 \
    sh -c 'trap : INT; sh "$1" --destination "$2"; echo "INSTALL_EXIT=$?"; sleep 0.3; echo STTY:; stty -a' \
    sh "$REPO_ROOT/install.sh" "$H/dest"
}

# The terminal settings printed after the install: raw mode would show -icanon.
terminal_restored() {
  settings=$(printf '%s\n' "$output" | sed -n '/^STTY:/,$p')
  [ -n "$settings" ]
  if printf '%s\n' "$settings" | grep -q -- '-icanon'; then return 1; fi
  if printf '%s\n' "$settings" | grep -q -- ' -echo '; then return 1; fi
}

@test "the first screen shows the default modules selected" {
  in_terminal '[["Select the optional modules","q"]]'
  [[ "$output" == *"> [x] editor"* ]]
  [[ "$output" == *"[ Submit ]"* ]]
}

@test "arrows, space and Enter pick a module and the choice is stored" {
  in_terminal '[
    ["Select the optional modules","n"],
    ["Selection cleared","\u001b[B"],
    ["> [ ] ghostty"," "],
    ["> [x] ghostty","\u001b[A\u001b[A"],
    ["> [ Submit ]","\n"],
    ["Install these modules?","y\n"]
  ]'
  [ "$status" -eq 0 ]
  [[ "$output" == *"You will install: ghostty"* ]]
  [[ "$output" == *"INSTALL_EXIT=0"* ]]
  grep -qF 'modules = ["ghostty"]' "$H/.config/chezmoi/chezmoi.toml"
  grep -q '^chezmoi init' "$CALLS"
}

@test "the terminal is back to normal after a completed install" {
  in_terminal '[
    ["Select the optional modules","\u001b[A"],
    ["> [ Submit ]","\n"],
    ["Install these modules?","y\n"]
  ]'
  [ "$status" -eq 0 ]
  terminal_restored
}

@test "q cancels the install and restores the terminal" {
  in_terminal '[["Select the optional modules","q"]]'
  [[ "$output" == *"Installation cancelled"* ]]
  [[ "$output" == *"INSTALL_EXIT=1"* ]]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
  terminal_restored
}

@test "Ctrl-C ends the install and restores the terminal" {
  in_terminal '[["Select the optional modules","\u0003"]]'
  [[ "$output" == *"INSTALL_EXIT=130"* ]]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
  terminal_restored
}
