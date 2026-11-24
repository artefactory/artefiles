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
if [ "\$1" = "-n" ] && [ "\$2" = "true" ]; then exit "\${SUDO_N_STATUS:-0}"; fi
exit 0
STUB
  # id names the groups in ID_GROUPS, so the admin-group test needs no real account.
  cat > "$BIN/id" << 'STUB'
#!/bin/sh
if [ "${1:-}" = "-Gn" ] && [ -n "${ID_GROUPS:-}" ]; then echo "$ID_GROUPS"; exit 0; fi
exec /usr/bin/id "$@"
STUB
  # chezmoi records init and runs for CHEZMOI_SECONDS seconds, long enough for
  # the keep-alive to refresh the ticket.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
echo "chezmoi \$*" >> "$CALLS"
case "\$1" in
  init) sleep "\${CHEZMOI_SECONDS:-0}"; exit "\${CHEZMOI_STATUS:-0}" ;;
  apply)
    sleep "\${APPLY_SECONDS:-0}"
    [ -z "\${APPLY_ERR:-}" ] || { echo "\$APPLY_ERR" >&2; echo "chezmoi: .chezmoiscripts/10-fail.sh: exit status 1" >&2; exit 1; }
    ;;
  execute-template) echo "\${CHEZMOI_EMAIL:-}" ;;
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

# bats `run` reads the install's output until every writer closes it, so a
# refresh loop still sleeping on that output holds the caller for a whole interval.
@test "the install returns at once, not after the refresh interval" {
  start=$SECONDS
  run_install ARTEFILES_SUDO_REFRESH=30
  [ "$status" -eq 0 ]
  [ $((SECONDS - start)) -lt 10 ]
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
  [[ "$output" == *"Ask your administrator for admin rights, then run the install again."* ]]
  [[ "$output" != *"Self Service"* ]]
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

# need_admin: macOS, before the apply, when the Self Service admin window may have closed.
# run_noterm runs the install with no terminal at all.
run_noterm() {
  run env -u CI -u CODESPACES -u ARTEFILES_SELECT_TTY HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:$PATH" "$@" sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
}

# sudo_v_lines: line numbers of the `sudo -v` calls.
sudo_v_lines() { grep -n '^sudo -v$' "$CALLS" | cut -d: -f1; }

# Each need_admin case is its own test: one install runs in about 2 s, so a
# table of them in one test would be slow and name no case when it fails.
@test "need_admin: a passing probe shows nothing" {
  run_install SUDO_N_STATUS=0
  [ "$status" -eq 0 ]
  [[ "$output" != *"ADMIN RIGHTS MISSING"* ]]
}

# The probe fails, Enter, sudo -v works: the install goes on and the refresh
# loop runs again after the second sudo -v.
@test "need_admin: Enter after the paused banner retries sudo and restarts the refresh" {
  printf '\n' > "$BATS_TEST_TMPDIR/tty"
  run_install SUDO_N_STATUS=1 ARTEFILES_TTY="$BATS_TEST_TMPDIR/tty" APPLY_SECONDS=0.6 ARTEFILES_SUDO_REFRESH=0.2
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADMIN RIGHTS MISSING - the install paused, nothing lost"* ]]
  [[ "$output" == *"Step: installing apps"* ]]
  [[ "$output" != *"Continuing without admin rights"* ]]
  [ "$(sudo_v_lines | wc -l | tr -d ' ')" = "2" ]
  second=$(sudo_v_lines | tail -1)
  [ -n "$(sed -n "$((second + 1)),\$p" "$CALLS" | grep '^sudo -n -v$')" ]
}

@test "need_admin: three refused sudo -v give up with status 0" {
  printf '\n\n\n' > "$BATS_TEST_TMPDIR/tty"
  run_install SUDO_N_STATUS=1 SUDO_V_STATUS=1 ARTEFILES_TTY="$BATS_TEST_TMPDIR/tty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Continuing without admin rights; steps that need it will fail."* ]]
  [ "$(sudo_v_lines | wc -l | tr -d ' ')" = "4" ]
  grep -q '^chezmoi apply' "$CALLS"
}

@test "need_admin: s + Enter skips at once" {
  printf 's\n' > "$BATS_TEST_TMPDIR/tty"
  run_install SUDO_N_STATUS=1 ARTEFILES_TTY="$BATS_TEST_TMPDIR/tty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Continuing without admin rights"* ]]
  [ "$(sudo_v_lines | wc -l | tr -d ' ')" = "1" ]
}

@test "an @artefact.com email gets the Self Service hint when sudo is refused" {
  printf '[user]\n\temail = dev@artefact.com\n' > "$H/.gitconfig"
  run_install SUDO_V_STATUS=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Open the Self Service app, request administrator rights, then run the install again."* ]]
  [[ "$output" != *"managed Mac"* ]]
  [[ "$output" != *"dev@artefact.com"* ]]
}

@test "no git email on a fresh Mac gives the generic hint under set -eu, never an abort" {
  run_install SUDO_V_STATUS=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ask your administrator for admin rights, then run the install again."* ]]
  [[ "$output" != *"Self Service"* ]]
}

@test "with no git email, the email chezmoi holds still gives the Self Service hint in need_admin" {
  printf 's\n' > "$BATS_TEST_TMPDIR/tty"
  run_install SUDO_N_STATUS=1 CHEZMOI_EMAIL=dev@artefact.com ARTEFILES_TTY="$BATS_TEST_TMPDIR/tty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Self Service"* ]]
  [[ "$output" != *"dev@artefact.com"* ]]
}

@test "need_admin: no terminal and not in the admin group says so and never waits" {
  run_noterm ID_GROUPS="staff everyone"
  [ "$status" -eq 0 ]
  [[ "$output" == *"This account is not an administrator; steps that need sudo will fail."* ]]
  [[ "$output" == *"Ask your administrator for admin rights, then run the install again."* ]]
  [[ "$output" != *"Self Service"* ]]
  [[ "$output" != *"could not finish"* ]]
  if grep -q '^sudo -n true' "$CALLS"; then return 1; fi
}

@test "need_admin: no terminal and in the admin group is silent" {
  run_noterm ID_GROUPS="staff admin everyone"
  [ "$status" -eq 0 ]
  [[ "$output" != *"ADMIN RIGHTS MISSING"* ]]
  [[ "$output" != *"not an administrator"* ]]
}

@test "need_admin runs before the backup and the apply" {
  run_install SUDO_N_STATUS=0
  [ "$status" -eq 0 ]
  gate=$(grep -n '^sudo -n true$' "$CALLS" | head -1 | cut -d: -f1)
  apply=$(grep -n '^chezmoi apply' "$CALLS" | head -1 | cut -d: -f1)
  [ -n "$gate" ] && [ "$gate" -lt "$apply" ]
}

@test "dry-run and Linux never run the admin gate" {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    ARTEFILES_SELECT_TTY="$ANSWERS" SUDO_N_STATUS=1 sh "$REPO_ROOT/install.sh" --dry-run
  [[ "$output" != *"ADMIN RIGHTS MISSING"* ]]
  run_install FAKE_OS=Linux SUDO_N_STATUS=1
  [[ "$output" != *"ADMIN RIGHTS MISSING"* ]]
}

@test "a failed apply that names sudo ends with the admin banner, after the failed-steps list" {
  run_install APPLY_ERR="sudo: a password is required"
  [ "$status" -ne 0 ]
  summary=$(printf '%s\n' "$output" | grep -n 'To retry only the failed ones' | cut -d: -f1)
  banner=$(printf '%s\n' "$output" | grep -n 'the install could not finish' | cut -d: -f1)
  [ -n "$banner" ] && [ "$banner" -gt "$summary" ]
  [[ "$(printf '%s\n' "$output" | tail -n 1)" == "+---"* ]]
}

@test "a failed apply without a sudo error prints no admin banner" {
  run_install APPLY_ERR="brew: formula not found"
  [ "$status" -ne 0 ]
  [[ "$output" != *"ADMIN RIGHTS MISSING"* ]]
  [ "$(printf '%s\n' "$output" | tail -n 1)" = "Every other step finished and is recorded. To retry only the failed ones, run: $BIN/chezmoi apply --keep-going --destination=$H/dest" ]
}

@test "a failed apply lists up to 3 error lines under What went wrong, before the retry command" {
  run_install APPLY_ERR="$(printf 'Error: one\nError: two\nError: three\nError: four\nnoise')"
  [ "$status" -ne 0 ]
  [[ "$output" == *"What went wrong:"* ]]
  [[ "$output" == *"  Error: three"* ]]
  [[ "$output" != *"  Error: four"* ]]
  [[ "$output" != *"  noise"* ]]
  wrong=$(printf '%s\n' "$output" | grep -n 'What went wrong' | cut -d: -f1)
  retry=$(printf '%s\n' "$output" | grep -n 'To retry only' | cut -d: -f1)
  [ "$wrong" -lt "$retry" ]
}

@test "a failed apply with no error or sudo line prints no What went wrong" {
  run_install APPLY_ERR="brew: formula not found"
  [ "$status" -ne 0 ]
  [[ "$output" != *"What went wrong"* ]]
}

# in_pty [VAR=VALUE ...]: the install with a real pseudo-terminal, so fd 4 is a tty.
in_pty() {
  command -v python3 > /dev/null 2>&1 || skip "python3 not available"
  run python3 "$REPO_ROOT/tests/helpers/pty_run.py" '[]' \
    env -u CI -u CODESPACES -u NO_COLOR HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="${PTH:-$BIN:$PATH}" TERM=xterm APPLY_ERR="sudo: a password is required" "$@" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest"
}

@test "failure colors appear on a terminal" {
  in_pty
  [[ "$output" == *$'\033['* ]]
  [[ "$output" == *"install step(s) failed"* ]]
}

@test "failure colors never appear under NO_COLOR" {
  in_pty NO_COLOR=1
  [[ "$output" != *$'\033['* ]]
  [[ "$output" == *"install step(s) failed"* ]]
}

@test "failure text is plain without a terminal" {
  run_install APPLY_ERR="sudo: a password is required"
  [[ "$output" != *$'\033['* ]]
}

# hide_chezmoi: chezmoi is no longer on PATH; install.sh "installs" it with a stub
# installer into Homebrew's bin, as it does on a fresh Mac, so it is only known by
# its absolute path.
hide_chezmoi() {
  mv "$BIN/chezmoi" "$BATS_TEST_TMPDIR/chezmoi-stub"
  printf '#!/bin/sh\ncp "%s" "$2/chezmoi"\nchmod +x "$2/chezmoi"\n' "$BATS_TEST_TMPDIR/chezmoi-stub" > "$BATS_TEST_TMPDIR/installer"
  printf '#!/bin/sh\ncase "$*" in *chezmoi.io/get*) cat "%s" ;; esac\nexit 0\n' "$BATS_TEST_TMPDIR/installer" > "$BIN/curl"
  chmod +x "$BIN/curl"
  PTH="$BIN:/usr/bin:/bin"
  NEW_CHEZMOI="$BATS_TEST_TMPDIR/brew/bin/chezmoi"
}

@test "a chezmoi that is not on PATH is named in full, with the PATH note just before the retry line" {
  hide_chezmoi
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$PTH" ARTEFILES_SELECT_TTY="$ANSWERS" ARTEFILES_SUDO_REFRESH=1 APPLY_ERR="boom" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest"
  [ "$status" -ne 0 ]
  note="chezmoi is not on your current shell's PATH yet, so use the full path."
  [[ "$output" == *"$note"* ]]
  [ "$(printf '%s\n' "$output" | tail -n 2 | head -n 1)" = "$note" ]
  [ "$(printf '%s\n' "$output" | tail -n 1)" = "Every other step finished and is recorded. To retry only the failed ones, run: $NEW_CHEZMOI apply --keep-going --destination=$H/dest" ]
}

# pos TEXT: offset of TEXT in $output, to compare the order lines were printed in.
pos() {
  pre=${output%%"$1"*}
  [ "$pre" != "$output" ] || {
    echo "missing: $1" >&2
    return 1
  }
  echo "${#pre}"
}

@test "on a terminal the summary prints in order: header, What went wrong, PATH note, retry line last" {
  hide_chezmoi
  in_pty APPLY_ERR="Error: it broke"
  a=$(pos "install step(s) failed")
  b=$(pos "What went wrong")
  c=$(pos "is not on your current shell's PATH")
  d=$(pos "To retry only the failed ones")
  [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && [ "$c" -lt "$d" ]
  # The retry line is the last text before the terminal closes.
  tail=${output#*"To retry only the failed ones"}
  [ "$(printf '%s' "$tail" | tr -d '\r\033' | grep -c 'ADMIN\|install step')" = "0" ]
}

@test "a failed brew bundle names the missing formula, with no admin banner" {
  err=$(printf '%s\n' \
    "Warning: 'azure-cli' formula is unreadable: No available formula with the name \"azure-cli\". Did you mean azure-dev or vue-cli?" \
    "Installing azure-cli has failed!" \
    '`brew bundle` failed! 1 Brewfile dependency failed to install' \
    "chezmoi: .chezmoiscripts/darwin/darwin-install-packages.sh: exit status 1")
  run_install APPLY_ERR="$err"
  [ "$status" -ne 0 ]
  [[ "$output" == *"What went wrong:"* ]]
  [[ "$output" == *"  Warning: 'azure-cli' formula is unreadable: No available formula"* ]]
  [[ "$output" == *"  Installing azure-cli has failed!"* ]]
  [[ "$output" == *'  `brew bundle` failed! 1 Brewfile dependency failed to install'* ]]
  [[ "$output" != *"ADMIN RIGHTS MISSING"* ]]
  [[ "$output" != *"To retry only the failed ones"* ]]
}

@test "a package failure says the rest finished, that a rerun fails the same way, and where the log is" {
  err=$(printf '%s\n' "Installing azure-cli has failed!" '`brew bundle` failed! 1 Brewfile dependency failed to install')
  run_install APPLY_ERR="$err"
  [ "$status" -ne 0 ]
  [[ "$output" == *"The rest of the install completed. Running it again will fail the same way until that package is fixed. Attach "*"install-"*".log to a bug report."* ]]
  [[ "$output" != *"Every other step finished"* ]]
  [[ "$output" != *"To retry only the failed ones"* ]]
}

@test "a package and a sudo failure together keep the retry line" {
  err=$(printf '%s\n' "Installing a has failed!" "sudo: a password is required" "chezmoi: .chezmoiscripts/darwin/darwin-install-packages.sh: exit status 1")
  run_install APPLY_ERR="$err"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Every other step finished and is recorded. To retry only the failed ones"* ]]
}

@test "a sudo failure keeps the retry advice and is not called a package failure" {
  run_install APPLY_ERR="sudo: a password is required"
  [ "$status" -ne 0 ]
  [[ "$output" != *"will fail the same way"* ]]
  [[ "$output" == *"Every other step finished and is recorded. To retry only the failed ones"* ]]
}

@test "three package failures and a sudo error: the banner prints and What went wrong stops at 3 lines" {
  err=$(printf '%s\n' "Installing a has failed!" "Installing b has failed!" "Installing c has failed!" "sudo: a password is required")
  run_install APPLY_ERR="$err"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ADMIN RIGHTS MISSING"* ]]
  [[ "$output" != *"will fail the same way"* ]]
  [ "$(printf '%s\n' "$output" | grep -c '^  Installing .* has failed!')" = "3" ]
  [[ "$output" != *"  sudo: a password is required"* ]]
}

@test "every sudo signature, including the ones sudo prints without a terminal, brings the admin banner" {
  for sig in "sudo: a password is required" "sudo: a terminal is required to read the password" \
    "sudo: no tty present and no askpass program specified" "dev is not in the sudoers file" \
    "Sorry, try again." "sudo: 3 incorrect password attempts"; do
    run_install APPLY_ERR="$sig"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ADMIN RIGHTS MISSING"* ]] || {
      echo "no banner for: $sig" >&2
      return 1
    }
  done
}
