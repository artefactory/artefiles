#!/usr/bin/env bats
# Every install run writes a log of its steps under the state folder, next to
# the backups; a failed run prints the log's path, and no token reaches it.
# Everything install.sh could change is stubbed.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  LOGS="$H/.local/state/artefiles"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  # An existing chezmoi config skips the module checklist, which is not under test.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"

  # chezmoi prints the tokens it was given, as a leaking step would. APPLY_FAIL
  # makes one apply step fail the way chezmoi reports it; INIT_FAIL fails init.
  # HOLD leaves a process behind that keeps init's stderr open for 2 seconds.
  cat > "$BIN/chezmoi" << 'STUB'
#!/bin/sh
case "$1" in
  init)
    echo "init sees GITHUB_TOKEN=${GITHUB_TOKEN:-} GH_TOKEN=${GH_TOKEN:-}" >&2
    [ ! -t 2 ] || echo "init has the terminal on stderr"
    [ -z "${HOLD:-}" ] || /bin/sleep 2 > /dev/null &
    [ -z "${INIT_FAIL:-}" ] || { echo "chezmoi: template: .chezmoi.toml.tmpl: broke" >&2; exit 1; }
    ;;
  apply)
    echo "apply sees GITHUB_TOKEN=${GITHUB_TOKEN:-}" >&2
    [ -z "${STRAY:-}" ] || echo "apply prints ${STRAY}" >&2
    echo "apply wrote .hello"
    [ -z "${APPLY_FAIL:-}" ] || { echo "chezmoi: .chezmoiscripts/10-fail.sh: exit status 3" >&2; exit 1; }
    ;;
  source-path) exit 1 ;;
esac
exit 0
STUB
  # gh is logged in unless GH_AUTH_FAIL is set; then it fails and its error
  # quotes the token, as a verbose client could. "auth token" prints GH_FAKE_TOKEN;
  # with LOG_GONE it first puts a folder where the log was, so the log can no
  # longer be opened by name.
  cat > "$BIN/gh" << 'STUB'
#!/bin/sh
case "$1 $2" in
  "auth status")
    [ -z "${GH_AUTH_FAIL:-}" ] || { echo "bad credentials for token ${GH_TOKEN:-}" >&2; exit 1; }
    ;;
  "auth token")
    if [ -n "${LOG_GONE:-}" ]; then
      for f in "$LOG_GONE"/install-*.log; do rm -f "$f" && mkdir "$f"; done
    fi
    [ -n "${GH_FAKE_TOKEN:-}" ] || exit 1
    echo "$GH_FAKE_TOKEN"
    ;;
esac
exit 0
STUB
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# run_install [VAR=VALUE ...] — install.sh with the stubs, no token variables
# and no terminal, so no checklist or prompt appears.
run_install() {
  run env -u CI -u CODESPACES -u GITHUB_TOKEN -u GH_TOKEN -u GITHUB_ACCESS_TOKEN \
    -u CHEZMOI_GITHUB_ACCESS_TOKEN -u XDG_STATE_HOME -u ARTEFILES_VERSION \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" "$@" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
}

# The one log the run left, or a failure when there is not exactly one.
the_log() {
  set -- "$LOGS"/install-*.log
  [ "$#" -eq 1 ] && [ -f "$1" ] || {
    echo "expected one log in $LOGS, found: $*" >&2
    return 1
  }
  printf '%s\n' "$1"
}

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$REPO_ROOT/install.sh"
}

@test "a failed apply step leaves a log that names it, and the error prints the log's path" {
  run_install APPLY_FAIL=1
  [ "$status" -ne 0 ]
  log=$(the_log)
  grep -q '10-fail.sh: exit status 3' "$log"
  grep -q 'chezmoi apply' "$log"
  [[ "$output" == *"$log"* ]]
  # The failed-steps summary stays the last thing printed.
  [ "$(printf '%s\n' "$output" | tail -n 1)" = "Every other step finished and is recorded. To retry only the failed ones: chezmoi apply --keep-going" ]
}

@test "a step that fails before chezmoi is named in the log, and the path is printed last" {
  run_install GH_AUTH_FAIL=1
  [ "$status" -ne 0 ]
  log=$(the_log)
  grep -q 'GitHub CLI authentication required' "$log"
  grep -qi 'failed.*GitHub login' "$log"
  [[ "$(printf '%s\n' "$output" | tail -n 1)" == *"$log"* ]]
}

@test "a failed chezmoi init is in the log" {
  run_install INIT_FAIL=1
  [ "$status" -ne 0 ]
  log=$(the_log)
  grep -q 'template: .chezmoi.toml.tmpl: broke' "$log"
  grep -qi 'failed.*chezmoi init' "$log"
  [[ "$output" == *"$log"* ]]
}

@test "the log records every step of a successful run and is readable only by the user" {
  run_install
  [ "$status" -eq 0 ]
  log=$(the_log)
  for step in preflight Homebrew 'GitHub CLI' 'GitHub login' 'chezmoi init' 'chezmoi apply'; do
    grep -q "== step: ${step}" "$log"
  done
  grep -q 'finished' "$log"
  [ "$(ls -l "$log" | cut -c1-10)" = "-rw-------" ]
  # A successful run does not print the path: nothing needs reporting.
  [[ "$output" != *"$log"* ]]
}

@test "what chezmoi apply prints on stdout reaches the log and the terminal" {
  run_install
  [ "$status" -eq 0 ]
  log=$(the_log)
  grep -q 'apply wrote .hello' "$log"
  [[ "$output" == *"apply wrote .hello"* ]]
}

@test "a log that can no longer be opened by name does not stop the install" {
  # The lent token restarts the log filter after the log was replaced.
  run_install GH_FAKE_TOKEN=lent-plain-secret-0002 LOG_GONE="$LOGS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"apply sees GITHUB_TOKEN="* ]]
  [[ "$output" == *"apply wrote .hello"* ]]
}

@test "a sleep without fractions still lets a failed run print the log's path" {
  # A POSIX sleep takes whole seconds only.
  printf '#!/bin/sh\ncase "$1" in *.*) exit 1 ;; esac\nexec /bin/sleep "$@"\n' > "$BIN/sleep"
  chmod +x "$BIN/sleep"
  run_install INIT_FAIL=1 HOLD=1
  [ "$status" -ne 0 ]
  log=$(the_log)
  grep -qi 'failed.*chezmoi init' "$log"
  [[ "$(printf '%s\n' "$output" | tail -n 1)" == *"$log"* ]]
}

@test "the terminal still gets every message the log records" {
  run_install APPLY_FAIL=1
  [[ "$output" == *"Running 'chezmoi init"* ]]
  [[ "$output" == *"10-fail.sh: exit status 3"* ]]
  [[ "$output" == *"apply wrote .hello"* ]]
}

@test "tokens from the environment never reach the log" {
  run_install GH_AUTH_FAIL=1 GH_TOKEN=env-gh-secret-value-1234
  log=$(the_log)
  grep -q 'bad credentials for token' "$log"
  if grep -q 'env-gh-secret-value-1234' "$log"; then return 1; fi

  rm -f "$LOGS"/install-*.log
  run_install GITHUB_TOKEN=env-github-secret-5678 APPLY_FAIL=1
  log=$(the_log)
  grep -q 'apply sees GITHUB_TOKEN=' "$log"
  if grep -q 'env-github-secret-5678' "$log"; then return 1; fi
}

@test "the token lent to chezmoi from gh never reaches the log" {
  # Not shaped like a GitHub token, so only its value can find it.
  run_install GH_FAKE_TOKEN=lent-plain-secret-0001
  [ "$status" -eq 0 ]
  log=$(the_log)
  grep -q 'apply sees GITHUB_TOKEN=' "$log"
  if grep -q 'lent-plain-secret-0001' "$log"; then return 1; fi
}

@test "a GitHub token the install never saw is kept out of the log too" {
  run_install STRAY=ghp_strayTokenValue0123456789 GH_FAKE_TOKEN=x
  [ "$status" -eq 0 ]
  log=$(the_log)
  grep -q 'apply prints' "$log"
  if grep -q 'strayTokenValue0123456789' "$log"; then return 1; fi
}

@test "only the most recent logs are kept" {
  mkdir -p "$LOGS"
  for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
    : > "$LOGS/install-200001${i}-000000-1.log"
  done
  run_install
  [ "$status" -eq 0 ]
  [ "$(ls "$LOGS"/install-*.log | wc -l | tr -d ' ')" -eq 10 ]
  [ ! -e "$LOGS/install-20000101-000000-1.log" ]
  [ -e "$LOGS/install-20000112-000000-1.log" ]
}

@test "a dry run writes no log" {
  run env -u CI -u CODESPACES -u XDG_STATE_HOME HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    sh "$REPO_ROOT/install.sh" --dry-run < /dev/null
  [ "$status" -eq 0 ]
  [ ! -e "$LOGS" ]
}

@test "an unwritable state folder does not stop the install" {
  mkdir -p "$H/.local"
  : > "$H/.local/state"
  run_install
  [ "$status" -eq 0 ]
}

@test "at a terminal, chezmoi init is logged once the config answers the module prompt" {
  command -v python3 > /dev/null 2>&1 || skip "python3 not available"
  # At a terminal install.sh asks for sudo and probes the network: both stubbed.
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sudo"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/curl"
  chmod +x "$BIN/sudo" "$BIN/curl"
  run python3 "$REPO_ROOT/tests/helpers/pty_run.py" '[]' \
    env -u CI -u CODESPACES -u GITHUB_TOKEN -u GH_TOKEN -u XDG_STATE_HOME -u ARTEFILES_VERSION \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" ARTEFILES_SUDO_REFRESH=1 INIT_FAIL=1 \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest"
  [ "$status" -ne 0 ]
  log=$(the_log)
  grep -q 'template: .chezmoi.toml.tmpl: broke' "$log"
  [[ "$output" == *"$log"* ]]
}

@test "at a terminal, chezmoi init keeps the terminal while the config does not answer the module prompt" {
  command -v python3 > /dev/null 2>&1 || skip "python3 not available"
  # A config without `modules` that still skips the checklist.
  printf '[data]\n  email = "me@example.com"\n' > "$H/.config/chezmoi/chezmoi.toml"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sudo"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/curl"
  chmod +x "$BIN/sudo" "$BIN/curl"
  run python3 "$REPO_ROOT/tests/helpers/pty_run.py" '[]' \
    env -u CI -u CODESPACES -u GITHUB_TOKEN -u GH_TOKEN -u XDG_STATE_HOME -u ARTEFILES_VERSION \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" ARTEFILES_SUDO_REFRESH=1 INIT_FAIL=1 \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"init has the terminal on stderr"* ]]
  [[ "$output" == *"template: .chezmoi.toml.tmpl: broke"* ]]
  log=$(the_log)
  grep -qi 'failed.*chezmoi init' "$log"
  if grep -q 'template: .chezmoi.toml.tmpl: broke' "$log"; then return 1; fi
  [[ "$output" == *"$log"* ]]
}
