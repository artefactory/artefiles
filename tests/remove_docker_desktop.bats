#!/usr/bin/env bats
# Tests for .chezmoiscripts/run_once_remove-docker-desktop.sh.tmpl: Docker's
# uninstaller removes the app and the data macOS protects; what still runs
# Docker Desktop (app, root helpers) fails the step so a rerun of install.sh
# finishes it; leftover data never fails it.

setup() {
  load 'helpers/setup'
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/home")
  seed_chezmoi_config "$H" '{}'
  STUBS="$BATS_TEST_TMPDIR/stubs"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$STUBS"
  # Nothing to quit: the script must not reach the real Docker process.
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/pgrep"
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/osascript"
  # sudo runs the command as the test user, so the fake system files can go.
  printf '#!/bin/sh\nexec "$@"\n' > "$STUBS/sudo"
  printf '#!/bin/sh\necho "launchctl $*" >> "%s"\n' "$CALLS" > "$STUBS/launchctl"
  printf '#!/bin/sh\necho "open $1" >> "%s"\n' "$CALLS" > "$STUBS/open"
  chmod +x "$STUBS"/*
  APP="$H/Applications/Docker.app"
  SYSLIB="$H/SystemLibrary"
  BIN="$H/usr-local-bin"
  GROUP="$H/Library/Group Containers/group.com.docker"
  CONTAINER="$H/Library/Containers/com.docker.docker"
  # Stands in for /dev/tty: the user's answer to the data-loss question.
  ANSWER="$BATS_TEST_TMPDIR/answer"
  echo y > "$ANSWER"
}

# render_for OS OTHER — the script rendered for OS, with the app, /Library and
# /usr/local/bin moved under the fake home so no test touches the real system.
render_for() {
  XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < <(sed -e "s/eq \.chezmoi\.os \"$1\"/true/g" -e "s/eq \.chezmoi\.os \"$2\"/false/g" \
      "$REPO_ROOT/.chezmoiscripts/run_once_remove-docker-desktop.sh.tmpl") \
    | sed -e "s|^DOCKER_APP=.*|DOCKER_APP=\"$APP\"|" \
      -e "s|^SYSTEM_LIBRARY=.*|SYSTEM_LIBRARY=\"$SYSLIB\"|" \
      -e "s|^LOCAL_BIN=.*|LOCAL_BIN=\"$BIN\"|" \
      -e "s|^TTY=.*|TTY=\"$ANSWER\"|" > "$BATS_TEST_TMPDIR/remove.sh"
  # The question never reads the real terminal.
  grep -qxF "TTY=\"$ANSWER\"" "$BATS_TEST_TMPDIR/remove.sh"
}

render_darwin() {
  render_for darwin linux
  # Every system path was moved under the fake home.
  grep -qxF "DOCKER_APP=\"$APP\"" "$BATS_TEST_TMPDIR/remove.sh"
  grep -qxF "SYSTEM_LIBRARY=\"$SYSLIB\"" "$BATS_TEST_TMPDIR/remove.sh"
  grep -qxF "LOCAL_BIN=\"$BIN\"" "$BATS_TEST_TMPDIR/remove.sh"
}

render_linux() {
  render_for linux darwin
  grep -qF '.config/docker-desktop' "$BATS_TEST_TMPDIR/remove.sh"
}

# refuse_rm PATTERN — an rm that fails like macOS's protection on any argument
# containing PATTERN and removes everything else.
refuse_rm() {
  cat > "$STUBS/rm" << EOF
#!/bin/sh
for a in "\$@"; do
  case "\$a" in *"$1"*) echo "rm: \$a: Operation not permitted" >&2; exit 1 ;; esac
done
exec /bin/rm "\$@"
EOF
  chmod +x "$STUBS/rm"
}

# fake_app [EXIT] — a Docker.app whose uninstaller records its call, removes the
# Group Container (it is in the app group, so macOS lets it) and exits EXIT.
fake_app() {
  mkdir -p "$APP/Contents/MacOS"
  cat > "$APP/Contents/MacOS/uninstall" << EOF
#!/bin/sh
echo "uninstall" >> "$CALLS"
/bin/rm -rf "$GROUP"
exit ${1:-0}
EOF
  chmod +x "$APP/Contents/MacOS/uninstall"
}

# run_script [VAR=value...] — the rendered script at a desk (CI unset).
run_script() {
  run env -u CI HOME="$H" PATH="$STUBS:$PATH" TERM_PROGRAM=ghostty "$@" sh "$BATS_TEST_TMPDIR/remove.sh"
}

@test "an installed app is removed with Docker's uninstaller, which also clears the protected data" {
  fake_app
  mkdir -p "$GROUP" "$CONTAINER"
  refuse_rm group.com.docker
  render_darwin
  run_script
  [ "$status" -eq 0 ]
  grep -qx uninstall "$CALLS"
  [ ! -e "$APP" ]
  [ ! -e "$GROUP" ]
  [ ! -e "$CONTAINER" ]
  [[ "$output" == *"removal complete"* ]]
  [[ "$output" == *"DELETES its containers, images and volumes"*"[y/N]"* ]]
  # Output captured by a pipe or a log carries no escape codes.
  [[ "$output" != *$'\033'* ]]
  if grep -q '^open' "$CALLS"; then return 1; fi
}

@test "data macOS refuses after the app is gone is reported and does not fail the install" {
  mkdir -p "$GROUP" "$CONTAINER"
  refuse_rm group.com.docker
  render_darwin
  run_script
  [ "$status" -eq 0 ]
  [ -d "$GROUP" ]
  [ ! -e "$CONTAINER" ]
  [[ "$output" == *"nothing to do"*"$GROUP"* ]]
  [[ "$output" != *"App Management"* ]]
  [ ! -e "$CALLS" ]
}

@test "the root helpers are stopped and removed even without the app" {
  mkdir -p "$SYSLIB/LaunchDaemons" "$SYSLIB/PrivilegedHelperTools"
  touch "$SYSLIB/LaunchDaemons/com.docker.vmnetd.plist" "$SYSLIB/PrivilegedHelperTools/com.docker.vmnetd" \
    "$SYSLIB/PrivilegedHelperTools/com.docker.socket"
  render_darwin
  run_script
  [ "$status" -eq 0 ]
  grep -qxF "launchctl bootout system $SYSLIB/LaunchDaemons/com.docker.vmnetd.plist" "$CALLS"
  [ ! -e "$SYSLIB/LaunchDaemons/com.docker.vmnetd.plist" ]
  [ ! -e "$SYSLIB/PrivilegedHelperTools/com.docker.vmnetd" ]
  [ ! -e "$SYSLIB/PrivilegedHelperTools/com.docker.socket" ]
}

@test "only CLI links into Docker.app are removed; a Homebrew docker stays" {
  mkdir -p "$BIN"
  ln -s "$APP/Contents/Resources/bin/docker" "$BIN/docker-compose"
  ln -s "/opt/homebrew/bin/docker" "$BIN/docker"
  render_darwin
  run_script
  [ "$status" -eq 0 ]
  [ ! -L "$BIN/docker-compose" ]
  [ -L "$BIN/docker" ]
}

@test "a failing uninstaller still ends with the app removed" {
  fake_app 1
  render_darwin
  run_script
  [ "$status" -eq 0 ]
  [ ! -e "$APP" ]
  [[ "$output" == *"uninstaller failed"* ]]
}

@test "an app macOS refuses fails the step, opens App Management, and a rerun after allowing finishes" {
  fake_app
  mkdir -p "$CONTAINER"
  printf '#!/bin/sh\necho "rm: $3: Operation not permitted" >&2\nexit 1\n' > "$STUBS/sudo"
  render_darwin
  run_script
  [ "$status" -ne 0 ]
  [ -d "$APP" ]
  [ ! -e "$CONTAINER" ]
  [[ "$output" == *"$APP"* ]]
  [[ "$output" == *"App Management"*"(ghostty)"* || "$output" == *"(ghostty)"*"App Management"* ]]
  [[ "$output" == *"run install.sh again"* ]]
  # The failure stands out in the install log, with numbered steps.
  [[ "$output" == *"!!! ======"*"still installed"*"1. "*"2. Quit the terminal"*"3. "*"!!! ======"* ]]
  [[ "$output" == *"System Settings is now open"* ]]
  [[ "$output" == *"Finder"* && "$output" == *"IT team"* ]]
  grep -qxF "open x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles" "$CALLS"

  # The user allows the terminal and reruns: chezmoi runs the failed script again.
  printf '#!/bin/sh\nexec "$@"\n' > "$STUBS/sudo"
  run_script
  [ "$status" -eq 0 ]
  [ ! -e "$APP" ]
}

@test "in CI a refused app still fails the step but opens no System Settings pane" {
  fake_app
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/sudo"
  render_darwin
  run_script CI=true
  [ "$status" -ne 0 ]
  [[ "$output" == *"!!! ======"*"App Management"* ]]
  [[ "$output" != *"System Settings is now open"* ]]
  if grep -q '^open' "$CALLS"; then return 1; fi
}

@test "with no Docker Desktop at all, nothing is touched" {
  render_darwin
  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Docker Desktop installation found"* ]]
  [ ! -e "$CALLS" ]
}

@test "on Linux, data that cannot be removed is reported and the step succeeds" {
  mkdir -p "$H/.config/docker-desktop" "$H/.docker/desktop"
  refuse_rm .config/docker-desktop
  render_linux
  run_script
  [ "$status" -eq 0 ]
  [ ! -e "$H/.docker/desktop" ]
  [[ "$output" == *"nothing to do"*"$H/.config/docker-desktop"* ]]
}

@test "on Linux, a package sudo cannot remove fails the step with sudo guidance" {
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/docker-desktop"
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/apt-get"
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/dpkg"
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/sudo"
  chmod +x "$STUBS"/*
  render_linux
  run_script
  [ "$status" -ne 0 ]
  [[ "$output" == *"!!! ======"*"docker-desktop package"*"sudo -v"*"run install.sh again"*"!!! ======"* ]]
  [[ "$output" != *"App Management"* ]]
}

@test "answering no keeps Docker Desktop, fails the step and explains how to save the data" {
  fake_app
  mkdir -p "$CONTAINER"
  echo n > "$ANSWER"
  render_darwin
  run_script
  [ "$status" -ne 0 ]
  [ -d "$APP" ]
  [ -d "$CONTAINER" ]
  [ ! -e "$CALLS" ]
  [[ "$output" == *"!!! ======"*"docker save"*"docker volume ls"*"Run install.sh again and answer y"*"!!! ======"* ]]
}

@test "with only Docker Desktop's data left, the question is still asked" {
  mkdir -p "$CONTAINER"
  echo n > "$ANSWER"
  render_darwin
  run_script
  [ "$status" -ne 0 ]
  [ -d "$CONTAINER" ]
}

@test "without a terminal or in CI, Docker Desktop is removed without asking" {
  fake_app
  render_darwin
  rm "$ANSWER"
  run_script
  [ "$status" -eq 0 ]
  [ ! -e "$APP" ]
  [[ "$output" != *"[y/N]"* ]]

  fake_app
  echo n > "$ANSWER"
  run_script CI=true
  [ "$status" -eq 0 ]
  [ ! -e "$APP" ]
  [[ "$output" != *"[y/N]"* ]]
}

@test "on Linux, answering no keeps the docker-desktop data" {
  mkdir -p "$H/.docker/desktop"
  echo n > "$ANSWER"
  render_linux
  run_script
  [ "$status" -ne 0 ]
  [ -d "$H/.docker/desktop" ]
  [[ "$output" == *"docker save"* ]]
}
