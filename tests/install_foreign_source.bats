#!/usr/bin/env bats
# A machine whose chezmoi source folder already holds another repository: the
# Quick Start must neither apply that repository in place of artefiles nor
# touch it, and must say which folder is in the way and what to do.
# chezmoi is the real one behind a stub that logs each call; no network.

setup() {
  load 'helpers/setup'
  H="$BATS_TEST_TMPDIR/home"
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/chezmoi.calls"
  SOURCE="$H/.local/share/chezmoi"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  REAL_CHEZMOI="$(command -v chezmoi)"
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
echo "\$*" >> "$CALLS"
exec "$REAL_CHEZMOI" "\$@"
STUB
  # gh is logged in and finds no release, so no version is fetched.
  printf '#!/bin/sh\nexit 0\n' > "$BIN/gh"
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# source_repo [MARKER] — a git repository in chezmoi's source folder, with its
# own config template and one dotfile; MARKER adds the file every artefiles
# clone (and fork) has.
source_repo() {
  mkdir -p "$SOURCE"
  printf '[data]\n  mine = true\n' > "$SOURCE/.chezmoi.toml.tmpl"
  echo mine > "$SOURCE/dot_mine"
  if [ "${1:-}" = marker ]; then
    mkdir -p "$SOURCE/.chezmoitemplates"
    echo 2 > "$SOURCE/.chezmoitemplates/modulesVersion"
  fi
  git -C "$SOURCE" init --quiet
  git -C "$SOURCE" add -A
  git -C "$SOURCE" -c user.email=t@e -c user.name=t -c commit.gpgsign=false -c core.hooksPath=/dev/null \
    commit --quiet -m mine
  git -C "$SOURCE" remote add origin https://example.com/someone/dotfiles.git
}

# quick_start — install.sh with no checkout around it, as the Quick Start runs it.
quick_start() {
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES -u ARTEFILES_VERSION -u GITHUB_TOKEN -u GH_TOKEN \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    XDG_STATE_HOME="$H/.local/state" XDG_CACHE_HOME="$H/.cache" \
    PATH="$BIN:$PATH" sh "$BATS_TEST_TMPDIR/install.sh" --destination "$H" < /dev/null
}

@test "another repository in chezmoi's source folder stops the install, untouched, and names the folder" {
  command -v git > /dev/null || skip "git not available"
  source_repo
  head_before=$(git -C "$SOURCE" rev-parse HEAD)
  quick_start
  [ "$status" -eq 1 ]
  [[ "$output" == *"$SOURCE holds another chezmoi repository"* ]]
  # A clone from before the marker existed is refused too: say how to update it.
  [[ "$output" == *"git -C $SOURCE pull"* ]]
  # Nothing ran: no chezmoi init or apply, no file written, the repository as it was.
  if grep -qE '^(init|apply)' "$CALLS"; then return 1; fi
  [ ! -e "$H/.mine" ]
  [ "$(git -C "$SOURCE" rev-parse HEAD)" = "$head_before" ]
  [ -z "$(git -C "$SOURCE" status --porcelain)" ]
}

@test "an artefiles clone or fork in chezmoi's source folder is reused" {
  command -v git > /dev/null || skip "git not available"
  source_repo marker
  quick_start
  [[ "$output" != *"holds another chezmoi repository"* ]]
  grep -q '^init' "$CALLS"
}
