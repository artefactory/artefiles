#!/usr/bin/env bats
# On macOS, at a terminal, install.sh asks for the sudo password once before
# Homebrew and keeps the ticket valid until it ends, so no later step prompts on
# its own. Everything it could change is stubbed, sudo included.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/calls"
  ANSWERS="$BATS_TEST_TMPDIR/answers"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  # An existing chezmoi config skips the module checklist, which is not under test.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"
  : > "$ANSWERS"

  # sudo records its arguments; -v fails when SUDO_V_STATUS is not 0.
  cat > "$BIN/sudo" << STUB
#!/bin/sh
echo "sudo \$*" >> "$CALLS"
if [ "\$1" = "-v" ]; then exit "\${SUDO_V_STATUS:-0}"; fi
exit 0
STUB
  # chezmoi records init and runs for CHEZMOI_SECONDS seconds, long enough for
  # the keep-alive to refresh the ticket.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
echo "chezmoi \$*" >> "$CALLS"
case "\$1" in
  init) sleep "\${CHEZMOI_SECONDS:-0}"; exit "\${CHEZMOI_STATUS:-0}" ;;
  source-path) exit 1 ;;
esac
exit 0
STUB
  printf '#!/bin/sh\necho "gh $*" >> "%s"\nexit 0\n' "$CALLS" > "$BIN/gh"
  printf '#!/bin/sh\necho "brew $*" >> "%s"\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$CALLS" "$BATS_TEST_TMPDIR" > "$BIN/brew"
  printf '#!/bin/sh\nif [ "${1:-}" = "-m" ]; then echo arm64; else echo "${FAKE_OS:-Darwin}"; fi\n' > "$BIN/uname"
  chmod +x "$BIN"/*
}

# run_install [VAR=VALUE ...] — run install.sh with the stubs, a stand-in
# terminal and a one-second refresh.
run_install() {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SELECT_TTY="$ANSWERS" ARTEFILES_SUDO_REFRESH=1 "$@" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest"
}

sudo_calls() { grep -c '^sudo ' "$CALLS" || true; }

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$REPO_ROOT/install.sh"
}

@test "the password is asked once, before chezmoi runs" {
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"administrator rights"* ]]
  [ "$(grep -c '^sudo -v$' "$CALLS")" = "1" ]
  first_sudo=$(grep -n '^sudo -v$' "$CALLS" | head -1 | cut -d: -f1)
  first_init=$(grep -n '^chezmoi init' "$CALLS" | head -1 | cut -d: -f1)
  [ "$first_sudo" -lt "$first_init" ]
}

@test "the ticket is refreshed while chezmoi runs" {
  run_install CHEZMOI_SECONDS=3
  [ "$status" -eq 0 ]
  [ "$(grep -c '^sudo -n -v$' "$CALLS")" -ge 1 ]
}

@test "the refresh stops when the install ends" {
  run_install CHEZMOI_SECONDS=2
  [ "$status" -eq 0 ]
  before=$(sudo_calls)
  sleep 3
  [ "$(sudo_calls)" = "$before" ]
}

@test "the refresh stops when chezmoi fails" {
  run_install CHEZMOI_SECONDS=1 CHEZMOI_STATUS=1
  [ "$status" -ne 0 ]
  before=$(sudo_calls)
  sleep 3
  [ "$(sudo_calls)" = "$before" ]
}

@test "a sudo that refuses does not stop the install" {
  run_install SUDO_V_STATUS=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"may not be allowed to use sudo"* ]]
  [[ "$output" == *"Ask your IT team"* ]]
  grep -q '^chezmoi init' "$CALLS"
  [ "$(grep -c '^sudo -n -v$' "$CALLS")" = "0" ]
}

@test "CI never asks for a password" {
  run_install CI=true
  [ "$status" -eq 0 ]
  [ "$(sudo_calls)" = "0" ]
}

@test "without a terminal nothing is asked" {
  run env -u CI -u CODESPACES -u ARTEFILES_SELECT_TTY HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:$PATH" sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
  [ "$status" -eq 0 ]
  [ "$(sudo_calls)" = "0" ]
}

@test "dry-run never asks for a password" {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    ARTEFILES_SELECT_TTY="$ANSWERS" sh "$REPO_ROOT/install.sh" --dry-run
  [ "$status" -eq 0 ]
  [ "$(sudo_calls)" = "0" ]
}

@test "Linux never asks for a password before the install" {
  run_install FAKE_OS=Linux
  [ "$status" -eq 0 ]
  [ "$(sudo_calls)" = "0" ]
}
