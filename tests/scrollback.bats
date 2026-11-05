#!/usr/bin/env bats
# Alt+K opens the terminal's output in $EDITOR: scrollback reads it from herdr,
# else tmux, else says how to get a source; `cmd | e` opens a pipe the same way.
# Both drop ANSI escapes and carriage-return redraws. herdr, tmux and the editor
# are stubs that log their arguments.

setup() {
  load 'helpers/setup'
  command -v fish > /dev/null || skip "fish is not installed"
  FUNCS="$REPO_ROOT/dot_config/fish/functions"
  BIN="$BATS_TEST_TMPDIR/bin"
  T="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$BIN" "$T"
  LOG="$BATS_TEST_TMPDIR/log"
  OUT="$BATS_TEST_TMPDIR/opened"
  : > "$LOG"
  # Each multiplexer stub logs its arguments and prints a colored line.
  for m in herdr tmux; do
    cat > "$BIN/$m" << 'EOF'
#!/bin/sh
printf '%s' "$(basename "$0")" >> "$LOG"; printf ' %s' "$@" >> "$LOG"; echo >> "$LOG"
printf 'make\n\033[31merror\033[0m: boom\n'
EOF
    chmod +x "$BIN/$m"
  done
  # The editor stub logs its arguments and copies the file it was given.
  cat > "$BIN/editor" << 'EOF'
#!/bin/sh
printf 'EDITOR' >> "$LOG"; printf ' %s' "$@" >> "$LOG"; echo >> "$LOG"
for a; do f=$a; done
cp "$f" "$OUT"
EOF
  chmod +x "$BIN/editor"
}

# in_fish [VAR=VALUE...] -- COMMAND — run COMMAND in a bare fish that autoloads
# the repository's functions, with only the given variables set.
in_fish() {
  local vars=()
  while [ "$1" != -- ]; do vars+=("$1"); shift; done
  shift
  run env -i HOME="$BATS_TEST_TMPDIR" PATH="$BIN:/usr/bin:/bin" TMPDIR="$T" \
    EDITOR="$BIN/editor" LOG="$LOG" OUT="$OUT" "${vars[@]}" "$(command -v fish)" --no-config \
    -c "set -p fish_function_path $FUNCS; $1"
}

@test "the strip filter drops colors, titles, charset and keypad escapes" {
  printf 'a\033[1;31mred\033[0m b\033[K\n\033]0;title\007x\033]8;;http://e\033\\link\033]8;;\033\\\n\033(Bq\033=\033>z\n' > "$BATS_TEST_TMPDIR/in"
  in_fish -- "__scrollback_strip < $BATS_TEST_TMPDIR/in"
  [ "$status" -eq 0 ]
  [ "$output" = $'ared b\nxlink\nqz' ]
}

@test "the strip filter keeps the last redraw of a line and drops CRLF endings" {
  printf '10%%\r50%%\r100%%\nwin\r\nend\r\r\n\t tab\n' > "$BATS_TEST_TMPDIR/in"
  in_fish -- "__scrollback_strip < $BATS_TEST_TMPDIR/in"
  [ "$status" -eq 0 ]
  [ "$output" = $'100%\nwin\nend\n\t tab' ]
}

@test "the source is herdr inside a herdr pane, even under tmux" {
  in_fish HERDR_PANE_ID=w1:p2 HERDR_ENV=1 TMUX=/tmp/t,1,0 -- __scrollback_source
  [ "$status" -eq 0 ]
  [ "$output" = herdr ]
}

@test "the source is tmux when herdr is absent from PATH" {
  rm "$BIN/herdr"
  in_fish HERDR_PANE_ID=w1:p2 TMUX=/tmp/t,1,0 -- __scrollback_source
  [ "$output" = tmux ]
}

@test "a herdr popup, which has HERDR_ENV but no pane id, is not a herdr source" {
  in_fish HERDR_ENV=1 -- __scrollback_source
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "scrollback reads the herdr pane's unwrapped scrollback and opens it at the end" {
  in_fish HERDR_PANE_ID=w1:p2 HERDR_ENV=1 -- scrollback
  [ "$status" -eq 0 ]
  grep -qx 'herdr pane read w1:p2 --source recent-unwrapped --lines 10000' "$LOG"
  grep -qE '^EDITOR \+ ' "$LOG"
  [ "$(cat "$OUT")" = $'make\nerror: boom' ]
}

@test "scrollback_lines sets how many herdr rows are read" {
  in_fish HERDR_PANE_ID=w1:p2 scrollback_lines=500 -- scrollback
  grep -qx 'herdr pane read w1:p2 --source recent-unwrapped --lines 500' "$LOG"
}

@test "scrollback reads the whole tmux history of the shell's own pane" {
  in_fish TMUX=/tmp/t,1,0 TMUX_PANE=%3 -- scrollback
  [ "$status" -eq 0 ]
  grep -qx 'tmux capture-pane -p -J -S - -t %3' "$LOG"
  [ "$(cat "$OUT")" = $'make\nerror: boom' ]
}

# fail_stub NAME — replace NAME's stub with one that prints an error and exits 3.
fail_stub() {
  cat > "$BIN/$1" << 'EOF'
#!/bin/sh
echo "$(basename "$0"): server not reachable" >&2
exit 3
EOF
  chmod +x "$BIN/$1"
}

@test "a failing herdr read prints herdr's error and opens no editor" {
  fail_stub herdr
  in_fish HERDR_PANE_ID=w1:p2 -- scrollback
  [ "$status" -ne 0 ]
  [[ "$output" == *"herdr: server not reachable"* ]]
  if grep -q EDITOR "$LOG"; then return 1; fi
  [ -z "$(ls -A "$T")" ]
}

@test "a failing tmux capture prints tmux's error and opens no editor" {
  fail_stub tmux
  in_fish TMUX=/tmp/t,1,0 -- scrollback
  [ "$status" -ne 0 ]
  [[ "$output" == *"tmux: server not reachable"* ]]
  if grep -q EDITOR "$LOG"; then return 1; fi
  [ -z "$(ls -A "$T")" ]
}

@test "scrollback deletes its temporary file once the editor exits" {
  in_fish TMUX=/tmp/t,1,0 -- scrollback
  [ "$status" -eq 0 ]
  [ -s "$OUT" ]
  [ -z "$(ls -A "$T")" ]
}

@test "without herdr or tmux, scrollback says how to get a source and fails" {
  in_fish -- scrollback
  [ "$status" -eq 1 ]
  [[ "$output" == *herdr* ]]
  [[ "$output" == *tmux* ]]
  [[ "$output" == *"cmd | e"* ]]
  [ "$(echo "$output" | wc -l)" -eq 1 ]
  if grep -q EDITOR "$LOG"; then return 1; fi
}

@test "e opens what is piped into it, without escapes, then deletes it" {
  printf '\033[1mbold\033[0m\nline 2\r\n' > "$BATS_TEST_TMPDIR/in"
  in_fish -- "e < $BATS_TEST_TMPDIR/in"
  [ "$status" -eq 0 ]
  [ "$(cat "$OUT")" = $'bold\nline 2' ]
  grep -qE '^EDITOR \+ ' "$LOG"
  [ -z "$(ls -A "$T")" ]
}

@test "the editor's own arguments in EDITOR are kept" {
  in_fish EDITOR="$BIN/editor --wait" TMUX=/tmp/t,1,0 -- scrollback
  [ "$status" -eq 0 ]
  grep -qE '^EDITOR --wait \+ ' "$LOG"
}

@test "Alt+K runs scrollback in default and insert mode, with no module selected" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_render "$H" dot_config/fish/config.fish.tmpl > "$BATS_TEST_TMPDIR/config.fish"
  grep -qE '^    bind alt-k \$__scrollback_key$' "$BATS_TEST_TMPDIR/config.fish"
  grep -qE '^        bind -M insert alt-k \$__scrollback_key$' "$BATS_TEST_TMPDIR/config.fish"
  fish -n "$BATS_TEST_TMPDIR/config.fish"
}

@test "Alt+K collides with no fish default binding" {
  run fish --no-config -c 'fish_default_key_bindings; bind alt-k; fish_vi_key_bindings; bind -M insert alt-k; bind -M default alt-k'
  [[ "$output" != *"bind --preset"* ]]
}

@test "the scrollback functions parse" {
  for f in scrollback e __scrollback_source __scrollback_strip __scrollback_open; do
    fish -n "$FUNCS/$f.fish"
  done
}

@test "the cheatsheet lists Alt+K and the e pipe" {
  grep -qF 'Alt+K' "$REPO_ROOT/CHEATSHEET.md"
  grep -qF 'cmd | e' "$REPO_ROOT/CHEATSHEET.md"
}
