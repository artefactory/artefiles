#!/usr/bin/env bats
# Tab / Shift-Tab in the picker (_fuzzy_complete_extend): grow the query to
# the next path segment of the highlighted candidate, or drop one segment.

setup() {
  load 'helpers/setup'
  command -v fish >/dev/null || skip "fish is not installed"
  FISH_DIR="$REPO_ROOT/dot_config/fish"
}

# $1 = query, $2 = candidate; or --back and a query.
ext() {
  fish --no-config -c "set -p fish_function_path '$FISH_DIR/functions'; _fuzzy_complete_extend \$argv" -- "$@"
}

@test "a glob query grows to the segment it matches, escaped" {
  run ext 'a/**/su' 'a/b c/sub/x.py'
  [ "$output" = 'a/b\ c/sub/' ]
}

@test "** matching zero directories" {
  run ext 'a/**/su' 'a/sub/f2.py'
  [ "$output" = 'a/sub/' ]
}

@test "a glob query over a file stops at the file" {
  run ext 'a/**/fi' 'a/b c/sub/file.py'
  [ "$output" = 'a/b\ c/sub/file.py' ]
}

@test "a plain prefix grows to the next /" {
  run ext 'a/b' 'a/b c/sub/'
  [ "$output" = 'a/b\ c/' ]
}

@test "an escaped query already at a / grows one segment" {
  run ext 'a/b\ c/' 'a/b c/sub/file.py'
  [ "$output" = 'a/b\ c/sub/' ]
}

@test "the last segment completes to the whole candidate" {
  run ext 'a/b\ c/sub/fi' 'a/b c/sub/file.py'
  [ "$output" = 'a/b\ c/sub/file.py' ]
}

@test "a leading ~ stays bare" {
  run ext '~/Doc' '~/Documents/x/'
  [ "$output" = '~/Documents/' ]
}

@test "a fuzzy query that is no prefix walks from the first segment" {
  run ext 'fil' 'a/b c/sub/file.py'
  [ "$output" = 'a/' ]
}

@test "no highlighted candidate keeps the query" {
  run ext 'a/**/zz' ''
  [ "$output" = 'a/**/zz' ]
}

@test "an escape other than a space grows the query too" {
  run ext 'a/p' 'a/p (1)/x.py'
  [ "$output" = 'a/p\ \(1\)/' ]
}

mode() {
  fish --no-config -c "set -p fish_function_path '$FISH_DIR/functions'; _fuzzy_complete_search_mode \$argv[1]" -- "$1"
}

@test "fzf search is off for globs and non-space escapes, on otherwise" {
  [ "$(mode 'a/**/su')" = disable-search ]
  [ "$(mode 'a/**/*')" = disable-search ]
  [ "$(mode 'a/*.py')" = disable-search ]
  [ "$(mode 'a/p\ \(1\)/')" = disable-search ]
  [ "$(mode 'a/q\&r/')" = disable-search ]
  [ "$(mode 'a/b\ c/sub/')" = enable-search ]
  [ "$(mode 'git ch')" = enable-search ]
  [ "$(mode '')" = enable-search ]
}

@test "--whole takes a zoxide row entire, with a trailing /" {
  run ext --whole 'arte' '/z/Work/arte facts'
  [ "$output" = '/z/Work/arte\ facts/' ]
  run ext --whole 'a/**/su' 'a/b c/sub/'
  [ "$output" = 'a/b\ c/sub/' ]
}

@test "back drops the last segment" {
  run ext --back 'a/b\ c/sub/fi'
  [ "$output" = 'a/b\ c/sub/' ]
  run ext --back 'a/b\ c/sub/'
  [ "$output" = 'a/b\ c/' ]
  run ext --back 'a/'
  [ -z "$output" ]
  run ext --back 'a/**/su'
  [ "$output" = 'a/**/' ]
}
