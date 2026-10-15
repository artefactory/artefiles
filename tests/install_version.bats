#!/usr/bin/env bats
# install.sh installs a release: ARTEFILES_VERSION when set, else the latest one,
# else the default branch with a warning. Everything it could change is stubbed.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  # An existing chezmoi config skips the module checklist, which is not under test.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"

  printf '#!/bin/sh\necho "chezmoi $*" >> "%s"\ncase "$1" in source-path) exit 1 ;; esac\nexit 0\n' "$CALLS" > "$BIN/chezmoi"
  # "release view" prints GH_FAKE_TAG and fails when it is unset (no release).
  cat > "$BIN/gh" << STUB
#!/bin/sh
echo "gh \$*" >> "$CALLS"
if [ "\$1 \$2" = "release view" ]; then
  [ -n "\${GH_FAKE_TAG:-}" ] || exit 1
  echo "\$GH_FAKE_TAG"
fi
exit 0
STUB
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# run_install [VAR=VALUE ...] — run a copy of install.sh away from any checkout,
# as the Quick Start does, with no terminal so no prompt appears.
run_install() {
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES -u ARTEFILES_VERSION HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" "$@" \
    sh "$BATS_TEST_TMPDIR/install.sh" --destination "$H/dest" < /dev/null
}

@test "the latest release is installed by default" {
  run_install GH_FAKE_TAG=v2026.10.0
  [ "$status" -eq 0 ]
  grep -qx 'chezmoi init --apply --branch=v2026.10.0 artefactory/artefiles --destination='"$H"'/dest' "$CALLS"
}

@test "ARTEFILES_VERSION picks the tag and gh is not asked for the latest" {
  run_install GH_FAKE_TAG=v2026.10.0 ARTEFILES_VERSION=v2026.09.0
  [ "$status" -eq 0 ]
  grep -q -- '--branch=v2026.09.0 ' "$CALLS"
  if grep -q '^gh release view' "$CALLS"; then return 1; fi
}

@test "ARTEFILES_VERSION=main installs the branch" {
  run_install ARTEFILES_VERSION=main
  [ "$status" -eq 0 ]
  grep -q -- '--branch=main ' "$CALLS"
}

@test "without a release the default branch is installed with a warning" {
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not find the latest release"* ]]
  grep -qx 'chezmoi init --apply artefactory/artefiles --destination='"$H"'/dest' "$CALLS"
}

@test "a value git could read as an option is refused before anything runs" {
  run_install ARTEFILES_VERSION=--upload-pack=evil
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a valid tag or branch"* ]]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}

@test "a value with spaces or shell characters is refused" {
  run_install 'ARTEFILES_VERSION=v1; echo hi'
  [ "$status" -ne 0 ]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}

@test "a checkout installs itself and ignores ARTEFILES_VERSION" {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" ARTEFILES_VERSION=v2026.09.0 \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARTEFILES_VERSION is ignored"* ]]
  grep -q -- "--source=$REPO_ROOT" "$CALLS"
  if grep -q -- '--branch' "$CALLS"; then return 1; fi
}

@test "a dry run names an explicit version without calling GitHub" {
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES HOME="$H" PATH="$BIN:$PATH" ARTEFILES_VERSION=v2026.09.0 GH_FAKE_TAG=v2026.10.0 \
    sh "$BATS_TEST_TMPDIR/install.sh" --dry-run < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"--branch=v2026.09.0"* ]]
  [ ! -s "$CALLS" ]
}

@test "the checklist clone is made at the chosen version" {
  command -v python3 > /dev/null 2>&1 || skip "python3 not available"
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sudo"
  chmod +x "$BIN/sudo"
  run python3 "$REPO_ROOT/tests/helpers/pty_run.py" '[]' \
    env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SUDO_REFRESH=1 ARTEFILES_VERSION=v2026.09.0 \
    sh -c 'rm -f "$1"; sh "$2" --destination "$3"' sh "$H/.config/chezmoi/chezmoi.toml" "$BATS_TEST_TMPDIR/install.sh" "$H/dest"
  grep -q 'gh repo clone artefactory/artefiles .*/chezmoi -- --branch v2026.09.0' "$CALLS"
}

# existing_clone — a clone left by an earlier install at $H/.local/share/chezmoi:
# tags v1 and v2 and a branch dev, checked out at v2. Its origin is a local repo.
existing_clone() {
  command -v git > /dev/null 2>&1 || skip "git not available"
  command -v python3 > /dev/null 2>&1 || skip "python3 not available"
  ORIGIN="$BATS_TEST_TMPDIR/origin"
  CLONE="$H/.local/share/chezmoi"
  git init --quiet "$ORIGIN"
  git -C "$ORIGIN" config user.email t@example.com
  git -C "$ORIGIN" config user.name t
  git -C "$ORIGIN" config commit.gpgsign false
  git -C "$ORIGIN" config tag.gpgsign false
  # select-modules.sh answers "no modules" without a prompt.
  printf '#!/bin/sh\necho "[]"\n' > "$ORIGIN/select-modules.sh"
  mkdir -p "$ORIGIN/.chezmoitemplates"
  echo 2 > "$ORIGIN/.chezmoitemplates/modulesVersion"
  : > "$ORIGIN/.chezmoi.toml.tmpl"
  echo v1 > "$ORIGIN/version"
  git -C "$ORIGIN" add -A
  git -C "$ORIGIN" commit --quiet -m one
  git -C "$ORIGIN" tag v1
  echo v2 > "$ORIGIN/version"
  git -C "$ORIGIN" commit --quiet -am two
  git -C "$ORIGIN" tag v2
  git -C "$ORIGIN" branch dev
  git clone --quiet "$ORIGIN" "$CLONE"
  # No config yet, so the checklist path runs.
  rm -f "$H/.config/chezmoi/chezmoi.toml"
}

# in_terminal_with VERSION — run install.sh in a pseudo-terminal with that ARTEFILES_VERSION.
in_terminal_with() {
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sudo"
  chmod +x "$BIN/sudo"
  run python3 "$REPO_ROOT/tests/helpers/pty_run.py" '[]' \
    env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SUDO_REFRESH=1 ARTEFILES_VERSION="$1" \
    sh -c 'sh "$1" --destination "$2"; echo "INSTALL_EXIT=$?"' sh "$BATS_TEST_TMPDIR/install.sh" "$H/dest"
}

@test "an existing clone is moved to the requested tag" {
  existing_clone
  in_terminal_with v1
  [[ "$output" == *"INSTALL_EXIT=0"* ]]
  [ "$(cat "$CLONE/version")" = v1 ]
  grep -q -- "--source=$CLONE" "$CALLS"
}

@test "an existing clone is moved to the tip of a requested branch" {
  existing_clone
  git -C "$ORIGIN" checkout --quiet dev
  echo dev > "$ORIGIN/version"
  git -C "$ORIGIN" commit --quiet -am dev-tip
  in_terminal_with dev
  [[ "$output" == *"INSTALL_EXIT=0"* ]]
  [ "$(cat "$CLONE/version")" = dev ]
}

@test "an existing clone is left alone when no version is chosen and there is no release" {
  existing_clone
  git -C "$CLONE" checkout --quiet --detach v1
  in_terminal_with ""
  [[ "$output" == *"INSTALL_EXIT=0"* ]]
  [ "$(cat "$CLONE/version")" = v1 ]
}

@test "an unknown version stops the install and names the problem" {
  existing_clone
  in_terminal_with v9
  [[ "$output" == *"v9 is not a tag or branch"* ]]
  [[ "$output" != *"INSTALL_EXIT=0"* ]]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}

@test "local changes in an existing clone stop the install instead of being lost" {
  existing_clone
  echo mine > "$CLONE/version"
  in_terminal_with v1
  [[ "$output" == *"Could not check out v1"* ]]
  [ "$(cat "$CLONE/version")" = mine ]
  if grep -q '^chezmoi init' "$CALLS"; then return 1; fi
}
