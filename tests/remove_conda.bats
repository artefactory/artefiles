#!/usr/bin/env bats
# Conda is removed, but only a real conda install is deleted: the folder that
# holds conda-meta/, never a folder taken from where the conda command sits.

setup() {
  load 'helpers/setup'
  H=$(mk_fake_home)
  seed_chezmoi_config "$H"
  SCRIPT="$BATS_TEST_TMPDIR/remove-conda.sh"
  chezmoi_render "$H" .chezmoiscripts/run_once_remove-conda.sh.tmpl > "$SCRIPT"
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BIN"
  : > "$CALLS"
  printf '#!/bin/sh\necho "brew $*" >> "%s"\n' "$CALLS" > "$BIN/brew"
  chmod +x "$BIN/brew"
}

teardown() {
  chmod -R u+w "$BATS_TEST_TMPDIR" 2> /dev/null || true
}

# fake_conda DIR — a conda command at DIR/bin/conda, found first on PATH.
fake_conda() {
  mkdir -p "$1/bin"
  printf '#!/bin/sh\n' > "$1/bin/conda"
  chmod +x "$1/bin/conda"
  ln -sf "$1/bin/conda" "$BIN/conda"
}

run_script() {
  run env HOME="$H" PATH="$BIN:/usr/bin:/bin" /bin/sh "$SCRIPT"
}

@test "a conda command outside a conda install deletes nothing" {
  usr="$BATS_TEST_TMPDIR/usr"
  fake_conda "$usr"
  touch "$usr/keep"
  run_script
  [ "$status" -eq 0 ]
  [ -f "$usr/keep" ]
  [ -f "$usr/bin/conda" ]
  [[ "$output" == *"nothing removed"* ]]
}

@test "the conda install that holds the command is deleted" {
  root="$BATS_TEST_TMPDIR/tools/miniforge3"
  fake_conda "$root"
  mkdir -p "$root/conda-meta"
  mkdir -p "$BATS_TEST_TMPDIR/tools/other"
  run_script
  [ "$status" -eq 0 ]
  [ ! -e "$root" ]
  [ -d "$BATS_TEST_TMPDIR/tools/other" ]
}

@test "a Homebrew conda is uninstalled through brew, never deleted by hand" {
  root="$BATS_TEST_TMPDIR/homebrew/Caskroom/miniconda/base"
  fake_conda "$root"
  mkdir -p "$root/conda-meta"
  run_script
  [ "$status" -eq 0 ]
  grep -qx 'brew uninstall --cask miniconda' "$CALLS"
  [ -d "$root/conda-meta" ]
}

@test "a conda install the user cannot remove is reported and the script goes on" {
  root="$BATS_TEST_TMPDIR/system/miniconda"
  fake_conda "$root"
  mkdir -p "$root/conda-meta"
  chmod u-w "$BATS_TEST_TMPDIR/system"
  run_script
  [ "$status" -eq 0 ]
  [ -d "$root/conda-meta" ]
  [[ "$output" == *"sudo rm -rf $(realpath "$root")"* ]]
  [ -f "$H/.local/share/conda_warning.txt" ]
}
