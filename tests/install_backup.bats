#!/usr/bin/env bats
# Before the first apply, install.sh copies every existing file the apply would
# change into a dated folder, lists what it would create, and prints how to
# undo the install. A rerun that changes nothing makes no folder.

setup() {
  load 'helpers/setup'
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  REAL_CHEZMOI="$(command -v chezmoi)"
  # chezmoi runs for real on the fake home, from the test copy of the source;
  # init is skipped (the config is seeded) and scripts and externals never run.
  # STATUS_FAIL makes `chezmoi status` fail.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
sub="\$1"; shift
case "\$sub" in
  init) exit 0 ;;
  --version) exec "$REAL_CHEZMOI" --version ;;
  source-path) echo "$(test_source)"; exit 0 ;;
  status) [ -z "\${STATUS_FAIL:-}" ] || { echo "chezmoi: status broke" >&2; exit 1; } ;;
esac
extra=""
[ "\$sub" = apply ] && extra="--exclude=scripts,externals"
exec "$REAL_CHEZMOI" "\$sub" --config "$H/.config/chezmoi/chezmoi.toml" --source "$(test_source)" \$extra "\$@"
STUB
  printf '#!/bin/sh\nexit 0\n' > "$BIN/gh"
  # brew shellenv would put Homebrew's own gh and chezmoi ahead of the stubs.
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
  printf '[user]\n  name = mine\n' > "$H/.gitconfig"
}

install() {
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    STATUS_FAIL="${STATUS_FAIL:-}" sh "$REPO_ROOT/install.sh" --destination "$H" < /dev/null
}

backups() { ls -d "$H"/.local/state/artefiles/backup-* 2> /dev/null; }

@test "an existing file is saved before the apply overwrites it, and the printed steps bring it back" {
  install
  [ "$status" -eq 0 ]
  [ "$(backups | wc -l)" -eq 1 ]
  B=$(backups)
  [ "$(grep -c 'name = mine' "$H/.gitconfig")" -eq 0 ]
  grep -q 'name = mine' "$B/files/.gitconfig"
  grep -qx '.config/starship.toml' "$B/created.txt"
  [ -s "$B/state.json" ]
  [[ "$output" == *"Your earlier files are saved in $B"* ]]
  [[ "$output" == *"chezmoi purge --force"* ]]
  # The printed steps 1 and 2.
  cp -Rp "$B/files/." "$H/"
  while IFS= read -r p; do [ -d "$H/$p" ] || rm -f "$H/$p"; done < "$B/created.txt"
  grep -q 'name = mine' "$H/.gitconfig"
  [ ! -e "$H/.config/starship.toml" ]
}

@test "a rerun that changes nothing makes no backup folder" {
  install
  [ "$status" -eq 0 ]
  install
  [ "$status" -eq 0 ]
  [ "$(backups | wc -l)" -eq 1 ]
  [[ "$output" != *"Your earlier files are saved"* ]]
}

@test "when the files to change cannot be listed, nothing is written" {
  STATUS_FAIL=1 install
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing was written"* ]]
  grep -q 'name = mine' "$H/.gitconfig"
  [ -z "$(backups)" ]
}
