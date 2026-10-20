#!/usr/bin/env bats
# install.sh runs every check it needs in one section, before it installs or
# writes anything, and prints every failure together. Everything the install
# could change is stubbed; nothing here reaches the network.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/calls"
  ANSWERS="$BATS_TEST_TMPDIR/answers"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  : > "$ANSWERS"
  # An existing chezmoi config skips the module checklist.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"

  stub sudo 'if [ "$1" = "-v" ]; then exit "${SUDO_V_STATUS:-0}"; fi'
  stub chezmoi 'case "$1" in source-path) exit 1 ;; --version) exit "${CHEZMOI_VERSION_STATUS:-0}" ;; esac'
  stub gh 'case "$*" in "auth status") printf "%s\n" "${GH_STATUS_OUT:-}" ;; api*) exit "${GH_API_STATUS:-0}" ;; "repo clone"*) exit "${GH_CLONE_STATUS:-0}" ;; esac'
  stub brew 'case "$1" in --prefix) echo "'"$BATS_TEST_TMPDIR"'/brew" ;; esac'
  stub curl 'exit "${CURL_STATUS:-0}"'
  stub uname 'if [ "${1:-}" = "-m" ]; then echo "${FAKE_ARCH:-arm64}"; else echo "${FAKE_OS:-Darwin}"; fi'

  # SYS holds the basic tools install.sh uses and nothing it checks for (git,
  # curl, brew), so a test can take one of those away with PATH="$BIN:$SYS".
  SYS="$BATS_TEST_TMPDIR/sys"
  mkdir -p "$SYS"
  for tool in cat dirname head mkdir mktemp rm sed; do
    ln -s "$(command -v "$tool")" "$SYS/$tool"
  done
}

teardown() {
  chmod -R u+w "$H" 2> /dev/null || :
}

# stub NAME BODY — a command in $BIN that records its arguments, then runs BODY.
stub() {
  printf '#!/bin/sh\necho "%s $*" >> "%s"\n%s\nexit 0\n' "$1" "$CALLS" "$2" > "$BIN/$1"
  chmod +x "$BIN/$1"
}

# run_install [VAR=VALUE ...] — install.sh with the stubs and a stand-in terminal.
run_install() {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SELECT_TTY="$ANSWERS" ARTEFILES_SUDO_REFRESH=1 "$@" \
    /bin/sh "$REPO_ROOT/install.sh" --destination "$H/dest"
}

# run_copy [VAR=VALUE ...] — install.sh copied out of the checkout, as the
# Quick Start runs it: chezmoi clones the repo and ARTEFILES_VERSION applies.
run_copy() {
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SELECT_TTY="$ANSWERS" ARTEFILES_SUDO_REFRESH=1 "$@" \
    /bin/sh "$BATS_TEST_TMPDIR/install.sh" --destination "$H/dest"
}

# nothing_changed — no stub that installs or applies anything was called.
nothing_changed() {
  if grep -Eq '^(brew install|gh repo clone|chezmoi init|chezmoi apply|sudo -v)' "$CALLS"; then
    cat "$CALLS" >&2
    return 1
  fi
}

@test "an unsupported system stops the install before anything runs" {
  run_install FAKE_OS=FreeBSD
  [ "$status" -eq 1 ]
  [[ "$output" == *"FreeBSD is not supported"* ]]
  nothing_changed
}

@test "an unsupported processor stops the install before anything runs" {
  run_install FAKE_ARCH=i686
  [ "$status" -eq 1 ]
  [[ "$output" == *"i686 processors are not supported"* ]]
  nothing_changed
}

@test "every failure is printed together" {
  run_install FAKE_OS=FreeBSD FAKE_ARCH=i686
  [ "$status" -eq 1 ]
  [[ "$output" == *"FreeBSD is not supported"* ]]
  [[ "$output" == *"i686 processors are not supported"* ]]
  nothing_changed
}

@test "without curl the install stops before anything runs, even with wget" {
  rm "$BIN/curl"
  stub wget ''
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:$SYS" ARTEFILES_SELECT_TTY="$ANSWERS" /bin/sh "$REPO_ROOT/install.sh" --destination "$H/dest"
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs curl to download its tools"* ]]
  [[ "$output" != *"cannot reach"* ]]
  if grep -q '^wget ' "$CALLS"; then return 1; fi
  nothing_changed
}

@test "a home that cannot be written stops the install" {
  chmod u-w "$H"
  run_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot write to $H"* ]]
  nothing_changed
}

@test "a local bin folder that cannot be written stops the install" {
  mkdir -p "$H/.local/bin"
  chmod u-w "$H/.local/bin"
  run_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot write to $H/.local/bin"* ]]
  nothing_changed
}

@test "an unreachable github.com stops the install before anything runs" {
  run_install CURL_STATUS=7
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach https://github.com"* ]]
  nothing_changed
}

@test "a reachable github.com lets the install go on" {
  run_install
  [ "$status" -eq 0 ]
  grep -q '^curl .*https://github.com' "$CALLS"
  grep -q '^chezmoi init' "$CALLS"
}

@test "a dry run never probes the network" {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    ARTEFILES_SELECT_TTY="$ANSWERS" /bin/sh "$REPO_ROOT/install.sh" --dry-run
  [ "$status" -eq 0 ]
  if grep -q '^curl ' "$CALLS"; then return 1; fi
}

@test "without a terminal the network is not probed" {
  run env -u CI -u CODESPACES -u ARTEFILES_SELECT_TTY HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:$PATH" /bin/sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
  [ "$status" -eq 0 ]
  if grep -q '^curl ' "$CALLS"; then return 1; fi
}

@test "a refused sudo stops the install when Homebrew still has to be installed" {
  rm "$BIN/brew"
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:$SYS" ARTEFILES_SELECT_TTY="$ANSWERS" SUDO_V_STATUS=1 \
    /bin/sh "$REPO_ROOT/install.sh" --destination "$H/dest"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Homebrew needs administrator rights"* ]]
  if grep -Eq '^(curl -fsSL .*Homebrew|chezmoi init)' "$CALLS"; then return 1; fi
}

@test "a token without the usual scopes warns and the install goes on" {
  run_install GH_STATUS_OUT="  - Token scopes: 'repo', 'workflow'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: the GitHub login lacks the scopes read:org gist"* ]]
  [[ "$output" == *"gh auth refresh"* ]]
  grep -q '^chezmoi init' "$CALLS"
}

@test "admin:org counts as read:org" {
  run_install GH_STATUS_OUT="  - Token scopes: 'admin:org', 'gist', 'repo'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"lacks the scopes"* ]]
}

@test "a token that lists no scopes gets no warning" {
  run_install GH_STATUS_OUT="  ✓ Logged in to github.com account someone (GH_TOKEN)"
  [ "$status" -eq 0 ]
  [[ "$output" != *"lacks the scopes"* ]]
}

@test "without git the Quick Start stops before cloning" {
  rm -f "$H/.config/chezmoi/chezmoi.toml"
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$SYS" ARTEFILES_SELECT_TTY="$ANSWERS" FAKE_OS=Linux \
    /bin/sh "$BATS_TEST_TMPDIR/install.sh" --destination "$H/dest"
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs git"* ]]
  nothing_changed
}

@test "chezmoi init writes the config, then chezmoi apply writes the files" {
  run_install
  [ "$status" -eq 0 ]
  init=$(grep -n '^chezmoi init' "$CALLS" | cut -d: -f1)
  apply=$(grep -n '^chezmoi apply' "$CALLS" | cut -d: -f1)
  [ -n "$init" ] && [ -n "$apply" ] && [ "$init" -lt "$apply" ]
  if grep -q '^chezmoi init.*--apply' "$CALLS"; then return 1; fi
  grep -qx "chezmoi apply --destination=$H/dest" "$CALLS"
}

@test "a dry run names both chezmoi steps" {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    /bin/sh "$REPO_ROOT/install.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running 'chezmoi init "* ]]
  [[ "$output" == *"Running 'chezmoi apply"* ]]
}

@test "a module conflict in chezmoi init leaves the existing config untouched" {
  cfg="$H/.config/chezmoi/chezmoi.toml"
  printf '[data]\n  name = "n"\n  email = "e@example.com"\n  modulesVersion = 2\n  modules = ["ghostty", "cmux"]\n' > "$cfg"
  touch -t 202001010000 "$cfg"
  before=$(cksum < "$cfg")
  stamp=$(ls -l "$cfg")
  # The real chezmoi, with the stubbed gh first on PATH.
  run env HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    "$(command -v chezmoi)" init --source "$REPO_ROOT" --config "$cfg" --destination "$H"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ghostty and cmux are alternatives"* ]]
  [ "$(cksum < "$cfg")" = "$before" ]
  [ "$(ls -l "$cfg")" = "$stamp" ]
}

@test "a Mac without Homebrew also needs the Homebrew installer to answer" {
  rm "$BIN/brew"
  stub curl 'case "$*" in *Homebrew/install*) exit 7 ;; esac'
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:$SYS" ARTEFILES_SELECT_TTY="$ANSWERS" \
    /bin/sh "$REPO_ROOT/install.sh" --destination "$H/dest"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach the Homebrew installer"* ]]
  [[ "$output" != *"cannot reach https://github.com"* ]]
  nothing_changed
}

@test "a classic token with no scopes at all gets the warning" {
  run_install GH_STATUS_OUT="  - Token scopes: none"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lacks the scopes repo read:org gist"* ]]
}

@test "the git check runs in the same section as the system checks" {
  rm -f "$H/.config/chezmoi/chezmoi.toml"
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$SYS" ARTEFILES_SELECT_TTY="$ANSWERS" FAKE_OS=Linux FAKE_ARCH=i686 \
    /bin/sh "$BATS_TEST_TMPDIR/install.sh" --destination "$H/dest"
  [ "$status" -eq 1 ]
  [[ "$output" == *"i686 processors are not supported"* ]]
  [[ "$output" == *"needs git"* ]]
  if grep -q '^gh ' "$CALLS"; then return 1; fi
}

@test "an invalid ARTEFILES_VERSION is reported with the other host checks" {
  run_copy ARTEFILES_VERSION=--upload-pack=evil FAKE_ARCH=i686
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a valid tag or branch name"* ]]
  [[ "$output" == *"i686 processors are not supported"* ]]
  nothing_changed
}

@test "a checkout ignores an invalid ARTEFILES_VERSION" {
  run_install ARTEFILES_VERSION=--upload-pack=evil
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARTEFILES_VERSION is ignored"* ]]
}

@test "a version that does not exist stops the install before chezmoi init" {
  run_copy ARTEFILES_VERSION=v9 GH_API_STATUS=1
  [ "$status" -eq 1 ]
  [[ "$output" == *"v9 is not a tag or branch of artefactory/artefiles"* ]]
  grep -q '^gh api repos/artefactory/artefiles/commits/v9' "$CALLS"
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}

@test "a version that exists lets chezmoi init run with it" {
  run_copy ARTEFILES_VERSION=v9
  [ "$status" -eq 0 ]
  grep -q '^chezmoi init --branch=v9 artefactory/artefiles' "$CALLS"
}

@test "a chezmoi that does not run stops the install before chezmoi init" {
  run_install CHEZMOI_VERSION_STATUS=1
  [ "$status" -eq 1 ]
  [[ "$output" == *"chezmoi does not run"* ]]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}

@test "a destination that cannot be written stops the install before chezmoi init" {
  mkdir -p "$H/dest"
  chmod u-w "$H/dest"
  run_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot write to $H/dest"* ]]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}

@test "a missing destination folder is created before chezmoi init" {
  run_install
  [ "$status" -eq 0 ]
  [ -d "$H/dest" ]
  grep -q '^chezmoi init' "$CALLS"
}

@test "a missing destination inside a folder that cannot be written stops the install" {
  mkdir -p "$H/locked"
  chmod u-w "$H/locked"
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SELECT_TTY="$ANSWERS" ARTEFILES_SUDO_REFRESH=1 \
    /bin/sh "$REPO_ROOT/install.sh" --destination "$H/locked/a/b"
  chmod u+w "$H/locked"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot create $H/locked/a/b: $H/locked cannot be written"* ]]
  [ ! -e "$H/locked/a" ]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}

@test "every check before chezmoi init is printed together" {
  mkdir -p "$H/dest"
  chmod u-w "$H/dest"
  run_copy ARTEFILES_VERSION=v9 GH_API_STATUS=1 CHEZMOI_VERSION_STATUS=1
  [ "$status" -eq 1 ]
  [[ "$output" == *"v9 is not a tag or branch"* ]]
  [[ "$output" == *"chezmoi does not run"* ]]
  [[ "$output" == *"cannot write to $H/dest"* ]]
}

@test "a dry run skips the checks before chezmoi init" {
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    ARTEFILES_VERSION=v9 GH_API_STATUS=1 /bin/sh "$BATS_TEST_TMPDIR/install.sh" --dry-run
  [ "$status" -eq 0 ]
  if grep -q '^gh api' "$CALLS"; then return 1; fi
}

@test "a failed checklist clone stops the install instead of going on" {
  rm -f "$H/.config/chezmoi/chezmoi.toml"
  run_copy GH_CLONE_STATUS=1
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not clone artefactory/artefiles"* ]]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}
