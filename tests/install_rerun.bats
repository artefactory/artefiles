#!/usr/bin/env bats
# install.sh can run again: a failing step does not skip the others, the failed
# steps are named with the command that retries only them, a rerun at the same
# version changes nothing, and a rerun that names a version moves the clone.

setup() {
  load 'helpers/setup'
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  BIN="$BATS_TEST_TMPDIR/bin"
  SRC="$BATS_TEST_TMPDIR/src"
  LOG="$BATS_TEST_TMPDIR/ran"
  mkdir -p "$BIN" "$SRC/.chezmoiscripts"
  : > "$LOG"
  # A small source: one file, a script that fails until $H/fixed exists, and
  # one that always works. Each script logs that it ran.
  echo hello > "$SRC/dot_hello"
  printf '#!/bin/sh\necho fail >> "%s"\n[ -e "%s/fixed" ] || exit 3\n' "$LOG" "$H" > "$SRC/.chezmoiscripts/run_onchange_10-fail.sh"
  printf '#!/bin/sh\necho ok >> "%s"\n' "$LOG" > "$SRC/.chezmoiscripts/run_onchange_20-ok.sh"
  REAL_CHEZMOI="$(command -v chezmoi)"
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
sub="\$1"; shift
case "\$sub" in
  init) exit 0 ;;
  --version) exec "$REAL_CHEZMOI" --version ;;
  source-path) echo "$SRC"; exit 0 ;;
esac
exec "$REAL_CHEZMOI" "\$sub" --config "$H/.config/chezmoi/chezmoi.toml" --source "$SRC" "\$@"
STUB
  printf '#!/bin/sh\nexit 0\n' > "$BIN/gh"
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

install() {
  run env -u CI -u CODESPACES -u ARTEFILES_VERSION HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    sh "$REPO_ROOT/install.sh" --destination "$H" < /dev/null
}

cz() { "$BIN/chezmoi" "$@" --destination "$H"; }

@test "a failing step does not skip the others, and the summary names it with the retry command" {
  config_before=$(cksum < "$H/.config/chezmoi/chezmoi.toml")
  install
  [ "$status" -ne 0 ]
  grep -qx ok "$LOG"
  [ "$(cat "$H/.hello")" = hello ]
  [[ "$output" == *"1 install step(s) failed:"*"  - .chezmoiscripts/10-fail.sh"* ]]
  [[ "$output" == *"To retry only the failed ones: chezmoi apply --keep-going"* ]]
  # The summary is the last thing printed.
  [ "$(printf '%s\n' "$output" | tail -n 1)" = "Every other step finished and is recorded. To retry only the failed ones: chezmoi apply --keep-going" ]
  [ "$(cksum < "$H/.config/chezmoi/chezmoi.toml")" = "$config_before" ]
  # The retry runs only the failed step.
  touch "$H/fixed"
  : > "$LOG"
  cz apply --keep-going
  [ "$(cat "$LOG")" = fail ]
}

@test "a second run at the same version changes nothing" {
  touch "$H/fixed"
  install
  [ "$status" -eq 0 ]
  before=$(cz state dump)
  : > "$LOG"
  install
  [ "$status" -eq 0 ]
  [ ! -s "$LOG" ]
  [ "$(cz state dump)" = "$before" ]
  cz verify
}

# A clone from an earlier install, with tags v1 and v2, at v2.
existing_clone() {
  ORIGIN="$BATS_TEST_TMPDIR/origin"
  CLONE="$H/.local/share/chezmoi"
  git init --quiet "$ORIGIN"
  for v in v1 v2; do
    echo "$v" > "$ORIGIN/version"
    git -C "$ORIGIN" add -A
    git -C "$ORIGIN" -c user.email=t@e -c user.name=t -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet -m "$v"
    git -C "$ORIGIN" -c tag.gpgsign=false tag "$v"
  done
  git clone --quiet "$ORIGIN" "$CLONE"
  git -C "$CLONE" checkout --quiet --detach v2
  # chezmoi's source is that clone; init and apply do nothing.
  printf '#!/bin/sh\ncase "$1" in source-path) echo "%s" ;; --version) echo v ;; esac\nexit 0\n' "$CLONE" > "$BIN/chezmoi"
}

quick_start_with() {
  cp "$REPO_ROOT/install.sh" "$BATS_TEST_TMPDIR/install.sh"
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_VERSION="$1" sh "$BATS_TEST_TMPDIR/install.sh" --destination "$H" < /dev/null
}

@test "a rerun over an existing config moves the clone to ARTEFILES_VERSION, then a second one stays put" {
  command -v git > /dev/null || skip "git not available"
  existing_clone
  quick_start_with v1
  [ "$status" -eq 0 ]
  [ "$(cat "$CLONE/version")" = v1 ]
  quick_start_with v1
  [ "$status" -eq 0 ]
  [[ "$output" == *"already at v1"* ]]
}
