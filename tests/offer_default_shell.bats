#!/usr/bin/env bats
# Changing the login shell needs sudo and chsh, so it is only ever offered as
# the very last step of install.sh, behind an explicit y/N prompt read from the
# terminal. Nothing in `chezmoi apply` may change it.

setup() {
  load 'helpers/setup'

  SCRIPT="$REPO_ROOT/offer-default-shell.sh"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$STUBS" "$BATS_TEST_TMPDIR/home"
  : > "$CALLS"

  printf '#!/bin/sh\nexit 0\n' > "$STUBS/fish"
  # sudo runs its command so `sudo tee -a $SHELLS_FILE` really appends.
  printf '#!/bin/sh\necho "sudo $*" >> "%s"\nexec "$@"\n' "$CALLS" > "$STUBS/sudo"
  printf '#!/bin/sh\necho "chsh $*" >> "%s"\n' "$CALLS" > "$STUBS/chsh"
  chmod +x "$STUBS"/*

  SHELLS_FILE="$BATS_TEST_TMPDIR/shells"
  printf '/bin/sh\n/bin/zsh\n' > "$SHELLS_FILE"
  ANSWER="$BATS_TEST_TMPDIR/answer"
}

# run_offer ANSWER_TEXT [VAR=VALUE ...] — run the script with a stubbed PATH,
# the answer fed through the fake terminal, and no CI variables.
run_offer() {
  local answer="$1"
  shift
  printf '%s\n' "$answer" > "$ANSWER"
  run env -i PATH="$STUBS:/usr/bin:/bin" HOME="$BATS_TEST_TMPDIR/home" \
    SHELL=/bin/zsh ARTEFILES_TTY="$ANSWER" ARTEFILES_SHELLS_FILE="$SHELLS_FILE" \
    "$@" sh "$SCRIPT"
}

chsh_calls() { grep -c '^chsh ' "$CALLS" || true; }

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$SCRIPT"
}

@test "an empty answer changes nothing and prints the manual commands" {
  run_offer ""
  [ "$status" -eq 0 ]
  [ "$(chsh_calls)" = "0" ]
  [[ "$output" == *"chsh -s $STUBS/fish"* ]]
}

@test "anything other than y or yes changes nothing" {
  for answer in n no N maybe " " "yep" "y es"; do
    run_offer "$answer"
    [ "$status" -eq 0 ]
    [ "$(chsh_calls)" = "0" ]
  done
}

@test "y registers fish in the shells file and runs chsh once" {
  run_offer y
  [ "$status" -eq 0 ]
  [ "$(chsh_calls)" = "1" ]
  grep -qx "chsh -s $STUBS/fish" "$CALLS"
  [ "$(grep -cxF "$STUBS/fish" "$SHELLS_FILE")" = "1" ]
}

@test "yes and Y are accepted" {
  run_offer yes
  [ "$(chsh_calls)" = "1" ]
  : > "$CALLS"
  run_offer Y
  [ "$(chsh_calls)" = "1" ]
}

@test "a fish already listed in the shells file is not appended again" {
  printf '%s\n' "$STUBS/fish" >> "$SHELLS_FILE"
  run_offer y
  [ "$(chsh_calls)" = "1" ]
  [ "$(grep -cxF "$STUBS/fish" "$SHELLS_FILE")" = "1" ]
  ! grep -q '^sudo tee' "$CALLS"
}

@test "without a terminal nothing is asked and nothing changes" {
  run_offer y ARTEFILES_TTY=/nonexistent/tty
  [ "$status" -eq 0 ]
  [ "$(chsh_calls)" = "0" ]
  [[ "$output" == *"chsh -s"* ]]
}

@test "CI and Codespaces never change the shell, even with a y" {
  run_offer y CI=true
  [ "$status" -eq 0 ]
  [ "$(chsh_calls)" = "0" ]
  run_offer y CODESPACES=true
  [ "$status" -eq 0 ]
  [ "$(chsh_calls)" = "0" ]
}

@test "nothing happens when fish is already the login shell" {
  run_offer y SHELL=/usr/bin/fish
  [ "$status" -eq 0 ]
  [ "$(chsh_calls)" = "0" ]
  [ -z "$output" ]
}

@test "nothing happens when fish is not installed" {
  rm "$STUBS/fish"
  run_offer y
  [ "$status" -eq 0 ]
  [ "$(chsh_calls)" = "0" ]
  [ -z "$output" ]
}

@test "a failing chsh never fails the install and prints the manual commands" {
  printf '#!/bin/sh\necho "chsh $*" >> "%s"\nexit 1\n' "$CALLS" > "$STUBS/chsh"
  run_offer y
  [ "$status" -eq 0 ]
  [[ "$output" == *"chsh -s"* ]]
}

@test "install.sh runs the offer after chezmoi, never exec's chezmoi" {
  if grep -nE '^\s*exec ' "$REPO_ROOT/install.sh"; then return 1; fi
  chezmoi_line=$(grep -nE '^"\$chezmoi" "\$@"' "$REPO_ROOT/install.sh" | head -1 | cut -d: -f1)
  offer_line=$(grep -n 'offer-default-shell.sh' "$REPO_ROOT/install.sh" | head -1 | cut -d: -f1)
  [ -n "$chezmoi_line" ]
  [ -n "$offer_line" ]
  [ "$chezmoi_line" -lt "$offer_line" ]
}

@test "no chezmoi script changes the login shell" {
  ! grep -rnE '\bchsh\b|/etc/shells' "$REPO_ROOT/.chezmoiscripts"
}

@test "the offer script is not managed by chezmoi" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  ! chezmoi_managed "$H" | grep -F 'offer-default-shell'
}
