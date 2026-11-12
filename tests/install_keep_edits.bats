#!/usr/bin/env bats
# A file the user changed since chezmoi last wrote it makes chezmoi ask before
# overwriting it, which fails without a terminal. When nobody can answer (no
# terminal, or --yes), install.sh stops before the backup and the apply, prints
# chezmoi's status for those files and, for each kind of change, the commands
# that resolve it. At a terminal without --yes, chezmoi asks as before.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/chezmoi.calls"
  ANSWERS="$BATS_TEST_TMPDIR/answers"
  STATUS="$BATS_TEST_TMPDIR/status"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  printf 'modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"
  # A terminal that answers every question with no.
  printf 'n\nn\nn\nn\n' > "$ANSWERS"
  # chezmoi status: one edited file (first column), one plain update.
  printf 'MM .config/fish/config.fish\n M .gitconfig\n' > "$STATUS"

  # chezmoi prints $STATUS for status and records each apply.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
case "\$1" in
  source-path) exit 1 ;;
  status) cat "$STATUS" ;;
  apply) echo apply >> "$CALLS" ;;
esac
exit 0
STUB
  printf '#!/bin/sh\nexit 0\n' > "$BIN/gh"
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# run_install [VAR=VALUE ...] -- [ARGS...] — install.sh with the stubs and no
# terminal, unless ARTEFILES_SELECT_TTY="$ANSWERS" is passed.
run_install() {
  local vars=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    vars+=("$1")
    shift
  done
  [ $# -eq 0 ] || shift
  run env -u CI -u CODESPACES -u ARTEFILES_YES -u ARTEFILES_SELECT_TTY \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" XDG_STATE_HOME="$H/.local/state" \
    PATH="$BIN:$PATH" ARTEFILES_TTY="$ANSWERS" GH_TOKEN=token "${vars[@]}" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" "$@" < /dev/null
}

@test "without a terminal an edited file stops the install before the backup and the apply" {
  run_install --
  [ "$status" -eq 1 ]
  [ ! -s "$CALLS" ]
  # The install log lives there too; only a backup folder would mean a backup.
  ! compgen -G "$H/.local/state/artefiles/backup-*" > /dev/null || return 1
  [[ "$output" == *"ERROR: 1 file(s) changed outside the install cannot be updated:"* ]]
  [[ "$output" == *"--destination=$H/dest diff <file>"* ]]
  [[ "$output" == *"--destination=$H/dest apply --force <file>"* ]]
  # A file only the update changes needs nothing from the user.
  [[ "$output" != *"/.gitconfig"* ]]
}

@test "each changed file is one line: status, full path, what the user and the update did" {
  printf 'MM .config/fish/config.fish\nMD .old.fish\nDA .gitconfig\nAD .removed\n' > "$STATUS"
  run_install --
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: 4 file(s)"* ]]
  [[ "$output" == *"  MM $H/dest/.config/fish/config.fish  you edited it; the update would replace your edits"* ]]
  [[ "$output" == *"  MD $H/dest/.old.fish  you edited it; the update would delete it"* ]]
  [[ "$output" == *"  DA $H/dest/.gitconfig  you deleted it; the update would write it again"* ]]
  [[ "$output" == *"  AD $H/dest/.removed  you created it again; the update would delete it"* ]]
  # forget, merge and re-add would edit the source clone.
  [[ "$output" != *"forget"* && "$output" != *"re-add"* && "$output" != *" merge"* ]]
}

@test "--yes stops on an edited file even at a terminal" {
  run_install ARTEFILES_SELECT_TTY="$ANSWERS" -- --yes
  [ "$status" -eq 1 ]
  [ ! -s "$CALLS" ]
  [[ "$output" == *"you edited it"* ]]
}

@test "at a terminal without --yes the apply runs and chezmoi asks" {
  run_install ARTEFILES_SELECT_TTY="$ANSWERS" --
  grep -qx apply "$CALLS"
  [[ "$output" != *"ERROR:"* ]]
}

@test "without a changed file the install runs the apply" {
  printf ' M .gitconfig\n' > "$STATUS"
  run_install --
  [ "$status" -eq 0 ]
  grep -qx apply "$CALLS"
  [[ "$output" != *"ERROR:"* ]]
}

@test "real chezmoi status marks an edited file MM and a deleted one DA, and apply fails on them without a terminal" {
  S="$BATS_TEST_TMPDIR/src"
  D="$BATS_TEST_TMPDIR/dest"
  mkdir -p "$S" "$D"
  printf 'team v1\n' > "$S/dot_a"
  printf 'team v1\n' > "$S/dot_b"
  cm() {
    env HOME="$BATS_TEST_TMPDIR" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg" chezmoi \
      --source "$S" --destination "$D" --config "$BATS_TEST_TMPDIR/cfg/c.toml" \
      --persistent-state "$BATS_TEST_TMPDIR/state.boltdb" "$@" < /dev/null
  }
  cm apply
  echo 'my edit' >> "$D/.a"
  rm "$D/.b"
  printf 'team v2\n' > "$S/dot_a"
  printf 'team v2\n' > "$S/dot_b"
  run cm status
  [[ "$output" == *"MM .a"* ]]
  [[ "$output" == *"DA .b"* ]]
  run cm apply --keep-going
  [ "$status" -ne 0 ]
}
