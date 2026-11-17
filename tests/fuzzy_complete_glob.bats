#!/usr/bin/env bats
# `**` tokens in the picker (_fuzzy_complete_glob, _fuzzy_complete_render):
# `**/` spans zero or more directories, `*`/`?` stay inside one segment, the
# last segment is a prefix, hidden and gitignored paths are skipped, and `cd`
# lists directories then matching zoxide entries. A token whose last segment
# holds a wildcard is left to fish's native Tab, which expands it in place.


setup() {
  load 'helpers/setup'
  command -v fish >/dev/null || skip "fish is not installed"
  command -v fd >/dev/null || skip "fd is not installed"
  FISH_DIR="$REPO_ROOT/dot_config/fish"
  bin=$(mktemp -d)
  root=$(mktemp -d)
  mkdir -p "$root/a/b c/sub" "$root/a/sub" "$root/a/.hid/sub" "$root/a/ign/sub"
  touch "$root/a/b c/sub/file.py" "$root/a/b c/sub/other.py" "$root/a/sub/f2.py" \
    "$root/a/x.py" "$root/a/.hid/sub/h.py" "$root/a/ign/sub/i.py"
  printf 'ign/\n' >"$root/a/.gitignore"
  # `zoxide query -l` prints $FAKE_ZOXIDE, so each case pins the database.
  printf '#!/bin/sh\nprintf "%%s" "$FAKE_ZOXIDE"\n' >"$bin/zoxide"
  chmod +x "$bin/zoxide"
  export PATH="$bin:$PATH" FAKE_ZOXIDE=''
}

teardown() { rm -rf "$bin" "$root"; }

# The reload shell: `fish --no-config` with only the function path set.
fsh() {
  cd "$root"
  # `--` keeps a leading `--dirs` from being read as a fish option.
  fish --no-config -c "set -p fish_function_path '$FISH_DIR/functions'; $1" -- "${@:2}"
}

glob() { fsh '_fuzzy_complete_glob $argv' "$@"; }

@test "regex: ** spans zero or more directories, * stays in a segment" {
  run fsh '_fuzzy_complete_glob_regex $argv[1]' '**/s*b/fi'
  [ "$status" -eq 0 ]
  [ "$output" = '^(?:.*/)?s[^/]*b/fi[^/]*$' ]
}

@test "regex: metacharacters in names are literal" {
  run fsh '_fuzzy_complete_glob_regex $argv[1]' '**/a.b+(c)'
  [ "$output" = '^(?:.*/)?a\.b\+\(c\)[^/]*$' ]
}

@test "partial last segment matches at any depth, names with spaces kept" {
  run glob 'a/**/fi'
  [ "$status" -eq 0 ]
  [ "$output" = 'a/b c/sub/file.py' ]
}

@test "** matches zero directories; directories end in /; output sorted" {
  run glob 'a/**/su'
  [ "$status" -eq 0 ]
  [ "$output" = $'a/b c/sub/\na/sub/' ]
}

@test "trailing / lists the children of every match" {
  run glob 'a/**/sub/'
  [ "$output" = $'a/b c/sub/file.py\na/b c/sub/other.py\na/sub/f2.py' ]
}

@test "hidden and gitignored paths are skipped" {
  run glob 'a/**/'
  [[ "$output" != *.hid* ]]
  [[ "$output" != *ign/* ]]
}

@test "a leading ~ stays as typed" {
  run fsh 'set HOME $argv[1]; _fuzzy_complete_glob $argv[2]' "$root" '~/a/**/x'
  [ "$output" = '~/a/x.py' ]
}

@test "--dirs lists directories only" {
  run glob --dirs 'a/**/'
  [ "$output" = $'a/b c/\na/b c/sub/\na/sub/' ]
}

@test "--dirs appends matching zoxide entries after the disk, deduplicated" {
  export FAKE_ZOXIDE="/z/work/proj/sub
$root/a/sub
/z/other/x
/z/a/deep/sublime
"
  run glob --dirs 'a/**/su'
  [ "$output" = $'a/b c/sub/\na/sub/\n/z/a/deep/sublime' ]
}

@test "--dirs with a base that does not exist still lists zoxide entries" {
  export FAKE_ZOXIDE=$'/z/work/proj/src\n/z/other/src\n'
  run glob --dirs 'work/**/sr'
  [ "$status" -eq 0 ]
  [ "$output" = /z/work/proj/src ]
}

@test "tokens without ** are not handled" {
  run glob 'a/sub/f'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "a wildcard in the last segment is left to native expand-all" {
  run glob 'a/**/*.py'
  [ "$status" -eq 1 ]
}

@test "? follows fish's qmark-noglob feature" {
  touch "$root/a/sub/f?.py"
  if fish --no-config -c 'status test-feature qmark-noglob'; then
    run glob 'a/**/f?'
    [ "$status" -eq 0 ]
    [ "$output" = 'a/sub/f?.py' ]
  else
    run glob 'a/**/f?'
    [ "$status" -eq 1 ]
  fi
}

@test "the reload renders glob candidates from prefix and query" {
  run fsh '_fuzzy_complete_render --split $argv' 'ls ' 'a/**/fi'
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | cut -f1)" = 'a/b c/sub/file.py' ]
}

@test "the reload falls back to complete -C for plain tokens" {
  run fsh '_fuzzy_complete_render --split $argv' 'ls ' 'a/x'
  [ "$(printf '%s' "$output" | cut -f1)" = 'a/x.py' ]
}

@test "the reload globs a wildcard in the last segment too" {
  run fsh '_fuzzy_complete_render --split $argv' 'ls ' 'a/**/*.py'
  [ "$(printf '%s\n' "$output" | cut -f1)" = $'a/b c/sub/file.py\na/b c/sub/other.py\na/sub/f2.py\na/x.py' ]
  run fsh '_fuzzy_complete_render --split $argv' 'ls ' 'a/*.py'
  [ "$(printf '%s' "$output" | cut -f1)" = 'a/x.py' ]
}

@test "the cd reload lists directories only" {
  run fsh '_fuzzy_complete_render --split $argv' 'cd ' 'a/**/'
  [[ "$output" != *.py* ]]
  [[ "$output" == *'a/sub/'* ]]
}
