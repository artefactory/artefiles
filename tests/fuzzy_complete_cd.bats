#!/usr/bin/env bats
# `cd` candidates (_fuzzy_complete_cd): local directories first, then zoxide
# entries, deduplicated; `--self` leads with the directory being browsed.
# A stub `zoxide` prints $FAKE_ZOXIDE for any query, so each case pins the
# database; completions/cd.fish's own zoxide rows must not leak through.


setup() {
  load 'helpers/setup'
  command -v fish >/dev/null || skip "fish is not installed"
  FISH_DIR="$REPO_ROOT/dot_config/fish"
  bin=$(mktemp -d)
  root=$(mktemp -d)
  mkdir -p "$root/Work/x" "$root/Work/y" "$root/Wobble" "$root/a/leaf" "$root/a/b c"
  printf '#!/bin/sh\nprintf "%%s" "$FAKE_ZOXIDE"\n' >"$bin/zoxide"
  chmod +x "$bin/zoxide"
  export PATH="$bin:$PATH" FAKE_ZOXIDE=''
}

teardown() { rm -rf "$bin" "$root"; }

# $1 = token, rest = flags; prints the candidate column only.
cdc() {
  cd "$root"
  fish --no-config -c "set -p fish_function_path '$FISH_DIR/functions'; set -p fish_complete_path '$FISH_DIR/completions'; _fuzzy_complete_cd \$argv[2..] -- 'cd ' \$argv[1]" -- "$@" | cut -f1
}

@test "one local match and no zoxide entry: one row" {
  run cdc Wor
  [ "$output" = Work/ ]
}

@test "one local match plus zoxide entries: local first, then zoxide" {
  export FAKE_ZOXIDE=$'/z/Work/proj\n/z/other/Workshop\n'
  run cdc Wor
  [ "$output" = $'Work/\n/z/Work/proj\n/z/other/Workshop' ]
}

@test "several local matches keep fish's order before zoxide" {
  export FAKE_ZOXIDE=$'/z/Wonder\n'
  run cdc Wo
  [ "$output" = $'Wobble/\nWork/\n/z/Wonder' ]
}

@test "a zoxide entry naming a listed directory is dropped" {
  export FAKE_ZOXIDE="$root/Work
/z/Work2
"
  run cdc Wor
  [ "$output" = $'Work/\n/z/Work2' ]
}

@test "no local match: zoxide entries only" {
  export FAKE_ZOXIDE=$'/z/arte/one\n/z/arte/two\n'
  run cdc arte
  [ "$output" = $'/z/arte/one\n/z/arte/two' ]
}

@test "a path token lists local directories only" {
  export FAKE_ZOXIDE=$'/z/elsewhere\n'
  run cdc Work/
  [ "$output" = $'Work/x/\nWork/y/' ]
  run cdc ./Wor
  [ "$output" = ./Work/ ]
}

@test "--self leads with the browsed directory" {
  run cdc Work/ --self
  [ "$output" = $'Work/\nWork/x/\nWork/y/' ]
}

@test "--self keeps a leaf directory selectable" {
  run cdc a/leaf/ --self
  [ "$output" = a/leaf/ ]
}

@test "--self unescapes the token" {
  run cdc 'a/b\ c/' --self
  [ "$output" = 'a/b c/' ]
}

@test "a glob token lists directories through the glob helper" {
  run cdc 'W*/'
  [ "$output" = $'Work/x/\nWork/y/' ]
}
