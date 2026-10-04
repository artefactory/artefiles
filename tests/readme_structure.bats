#!/usr/bin/env bats
# The README must tell users that chezmoi manages their configs, list the
# prerequisites before the installation, document the chezmoi commands right
# after it, and explain how to fork or clone the repo to personalize it.

setup() {
  load 'helpers/setup'
  README="$REPO_ROOT/README.md"
}

# section TITLE — the body of the "## TITLE" section, up to the next "## ".
section() {
  awk -v t="## $1" '$0 == t {on=1; next} /^## / {on=0} on' "$README"
}

# line_of TITLE — the line number of the "## TITLE" heading (empty if absent).
line_of() { grep -nxF "## $1" "$README" | head -1 | cut -d: -f1; }

@test "the intro states that chezmoi manages the configs" {
  head -10 "$README" | grep -qiE 'managed by .*chezmoi'
}

@test "a one-line pickup near the top links to the chezmoi commands" {
  head -12 "$README" | grep -qF '(#using-chezmoi)'
}

@test "sections come in the order prerequisites, install, chezmoi, personalize, modules" {
  p=$(line_of "Prerequisites")
  q=$(line_of "Quick Start")
  c=$(line_of "Using chezmoi")
  z=$(line_of "Clone and personalize")
  m=$(line_of "Modular Architecture")
  for n in "$p" "$q" "$c" "$z" "$m"; do [ -n "$n" ] || return 1; done
  [ "$p" -lt "$q" ] && [ "$q" -lt "$c" ] && [ "$c" -lt "$z" ] && [ "$z" -lt "$m" ]
}

@test "there is one Prerequisites section and no separate Chezmoi Basics section" {
  [ "$(grep -cxF '## Prerequisites' "$README")" -eq 1 ]
  [ -z "$(line_of "Chezmoi Basics")" ]
}

@test "Using chezmoi documents the day-to-day commands" {
  body=$(section "Using chezmoi")
  for cmd in 'chezmoi init && chezmoi apply' 'chezmoi status' 'chezmoi diff' 'chezmoi edit' 'chezmoi apply' 'chezmoi update'; do
    printf '%s\n' "$body" | grep -qF "$cmd" || { echo "missing: $cmd" >&2; return 1; }
  done
}

@test "Clone and personalize covers fork, init, edit, diff, apply and upstream updates" {
  body=$(section "Clone and personalize")
  for word in 'fork' 'chezmoi init --apply' 'chezmoi edit' 'chezmoi diff' 'chezmoi apply' 'upstream'; do
    printf '%s\n' "$body" | grep -qiF "$word" || { echo "missing: $word" >&2; return 1; }
  done
}

@test "every in-page link points to an existing heading" {
  slugs=$(grep -E '^#{2,4} ' "$README" | sed -E 's/^#+ //; s/\([^)]*\)//g' | tr 'A-Z' 'a-z' \
    | sed -E 's/[^a-z0-9 _-]//g; s/ +$//; s/ /-/g')
  while read -r a; do
    printf '%s\n' "$slugs" | grep -qxF "$a" || { echo "dangling anchor: #$a" >&2; return 1; }
  done < <(grep -oE '\]\(#[a-z0-9_-]+\)' "$README" | sed -E 's/^\]\(#//; s/\)$//' | sort -u)
}
