#!/usr/bin/env bats
# install.sh --restore FOLDER undoes an install from the backup folder it made:
# it copies the saved files back, deletes what the install created and removes
# chezmoi's config and state, after a confirmation. It never deletes a source
# checkout of the user's own.

setup() {
  load 'helpers/setup'
  H="$BATS_TEST_TMPDIR/h"
  B="$H/.local/state/artefiles/backup-20261022-120000"
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  ANSWER="$BATS_TEST_TMPDIR/answer"
  mkdir -p "$BIN" "$B/files" "$H/.config/chezmoi" "$H/.config/fish" "$H/.local/share/chezmoi"
  : > "$CALLS"
  # The backup: the user's own .gitconfig, and what the install created.
  printf '[user]\n  name = mine\n' > "$B/files/.gitconfig"
  printf '%s\n' .config/fish .config/fish/config.fish .config/starship.toml > "$B/created.txt"
  # The home after the install, plus a file the user added since.
  printf '[user]\n  name = artefiles\n' > "$H/.gitconfig"
  : > "$H/.config/fish/config.fish"
  : > "$H/.config/fish/mine.fish"
  : > "$H/.config/starship.toml"
  : > "$H/.config/chezmoi/chezmoi.toml"
  # chezmoi: source-path prints $SOURCE; purge is recorded.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
echo "chezmoi \$*" >> "$CALLS"
case "\$1" in source-path) echo "\$SOURCE" ;; esac
exit 0
STUB
  # A run that went on to install would find these instead of the real tools.
  printf '#!/bin/sh\necho "gh $*" >> "%s"\nexit 0\n' "$CALLS" > "$BIN/gh"
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sudo"
  chmod +x "$BIN"/*
  SOURCE="$H/.local/share/chezmoi"
}

# restore ANSWER [ARGS...] — run install.sh --restore at a terminal that answers ANSWER.
restore() {
  printf '%s\n' "$1" > "$ANSWER"
  shift
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" SOURCE="$SOURCE" ARTEFILES_SELECT_TTY=1 ARTEFILES_TTY="$ANSWER" \
    sh "$REPO_ROOT/install.sh" --restore "$@"
}

@test "y copies the saved files back, deletes what the install created and purges chezmoi's clone" {
  restore y "$B"
  [ "$status" -eq 0 ]
  grep -q 'name = mine' "$H/.gitconfig"
  [ ! -e "$H/.config/starship.toml" ]
  [ ! -e "$H/.config/fish/config.fish" ]
  # A created folder that now holds a file of the user's stays.
  [ -f "$H/.config/fish/mine.fish" ]
  grep -qx 'chezmoi purge --force' "$CALLS"
  [[ "$output" == *"copy back:"*".gitconfig"* ]]
  [[ "$output" == *"Software the install added"*"is not removed"* ]]
}

@test "a source checkout of the user's own is kept: only chezmoi's config and state go" {
  SOURCE="$BATS_TEST_TMPDIR/my-artefiles"
  mkdir -p "$SOURCE"
  restore y "$B"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'purge' "$CALLS")" -eq 0 ]
  [ -d "$SOURCE" ]
  [ ! -e "$H/.config/chezmoi" ]
  [[ "$output" == *"$SOURCE is kept"* ]]
}

@test "any other answer than y changes nothing" {
  restore n "$B"
  [ "$status" -ne 0 ]
  grep -q 'name = artefiles' "$H/.gitconfig"
  [ -e "$H/.config/starship.toml" ]
  ! grep -q 'purge' "$CALLS"
}

@test "a folder without created.txt is refused and nothing changes" {
  rm "$B/created.txt"
  restore y "$B"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not an artefiles backup folder"* ]]
  grep -q 'name = artefiles' "$H/.gitconfig"
}

@test "without a terminal nothing changes" {
  run env -u CI -u CODESPACES -u ARTEFILES_SELECT_TTY HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:$PATH" SOURCE="$SOURCE" sh "$REPO_ROOT/install.sh" --restore "$B" < /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"needs a terminal; nothing was changed"* ]]
  grep -q 'name = artefiles' "$H/.gitconfig"
  [ -e "$H/.config/starship.toml" ]
}
