#!/usr/bin/env bats
# The manual steps in README.md and CHEATSHEET.md are Runme cells
# (https://docs.runme.dev): a fenced block with a JSON annotation after the
# language. Runme scans every Markdown file of the project and cell names are
# global, so names must be unique across both files. `runme run --all` runs
# every cell not marked excludeFromRunAll, so cells that install or destroy
# must be excluded.

setup() {
  load 'helpers/setup'
  DOCS=("$REPO_ROOT/README.md" "$REPO_ROOT/CHEATSHEET.md")
}

# annotations — the JSON annotation of every annotated fence, one per line.
annotations() {
  sed -nE 's/^[[:space:]]*```[a-z]+ +(\{.*\})[[:space:]]*$/\1/p' "${DOCS[@]}"
}

# cell_body NAME — the lines of the cell named NAME. Fences may be indented
# (a block inside a list item).
cell_body() {
  awk -v n="\"name\":\"$1\"" '
    /^[[:space:]]*```/ && on { exit }
    on { sub(/^[[:space:]]+/, ""); print }
    /^[[:space:]]*```[a-z]+ +\{/ && index($0, n) { on = 1 }
  ' "${DOCS[@]}"
}

# each_named_cell — "name<TAB>annotation" for every named cell.
each_named_cell() {
  annotations | jq -r 'select(.name) | [.name, tojson] | @tsv'
}

@test "every annotation is valid JSON" {
  while IFS= read -r a; do
    printf '%s' "$a" | jq -e 'type == "object"' > /dev/null || { echo "bad annotation: $a" >&2; return 1; }
  done < <(annotations)
}

@test "cell names are unique across README and CHEATSHEET" {
  dups=$(annotations | jq -r '.name // empty' | sort | uniq -d)
  [ -z "$dups" ] || { echo "duplicate cell names: $dups" >&2; return 1; }
}

@test "the manual steps are named cells" {
  names=$(annotations | jq -r '.name // empty')
  for n in install chezmoi-init-direct follow-upstream \
    chezmoi-check chezmoi-edit chezmoi-update chezmoi-modules publish-changes \
    chezmoi-doctor chezmoi-add chezmoi-merge chezmoi-update-preview chezmoi-reset-file \
    chezmoi-list-managed chezmoi-destroy fish-default-macos fish-default-linux; do
    printf '%s\n' "$names" | grep -qxF "$n" || { echo "missing cell: $n" >&2; return 1; }
  done
}

# Runme lists a fence of any language as a cell, and `runme run --all` runs an
# unnamed one too (it printed a yaml example), so the rule covers every language.
@test "every fenced block with a language is either a named cell or ignored" {
  for f in "${DOCS[@]}"; do
    bare=$(grep -nE '^[[:space:]]*```[A-Za-z0-9_+-]+[[:space:]]*$' "$f" || true)
    [ -z "$bare" ] || { echo "unannotated blocks in $f:" >&2; echo "$bare" >&2; return 1; }
    unnamed=$(sed -nE 's/^[[:space:]]*```[A-Za-z0-9_+-]+ +(\{.*\})[[:space:]]*$/\1/p' "$f" \
      | jq -c 'select((.name | not) and .ignore != "true")')
    [ -z "$unnamed" ] || { echo "block neither named nor ignored in $f: $unnamed" >&2; return 1; }
  done
}

@test "cells that change anything are excluded from run --all" {
  # What changes the home directory, the source directory, a remote or the
  # login shell, or opens an editor.
  changes='chezmoi (-v )?(apply|update|add|re-add|forget|edit|merge|init|destroy|purge)|install\.sh|chsh |git (-- )?(add|commit|push|pull|remote add)'
  while IFS=$'\t' read -r name a; do
    if cell_body "$name" | grep -qE "$changes"; then
      [ "$(printf '%s' "$a" | jq -r '.excludeFromRunAll // empty')" = "true" ] \
        || { echo "cell not excluded from run --all: $name" >&2; return 1; }
    fi
  done < <(each_named_cell)
}

@test "the cells run --all keeps are non-interactive and tagged check" {
  while IFS=$'\t' read -r name a; do
    [ "$(printf '%s' "$a" | jq -r '.excludeFromRunAll // empty')" = "true" ] && continue
    [ "$(printf '%s' "$a" | jq -r '.interactive // empty')" = "false" ] \
      || { echo "cell run by --all is interactive: $name" >&2; return 1; }
    printf '%s' "$a" | jq -e '.tag // "" | split(",") | index("check")' > /dev/null \
      || { echo "cell run by --all is not tagged check: $name" >&2; return 1; }
  done < <(each_named_cell)
}

@test "no cell opens a subshell with chezmoi cd: runme would wait on it" {
  while IFS=$'\t' read -r name _; do
    if cell_body "$name" | grep -qE '^chezmoi cd([[:space:]]|$)'; then
      echo "chezmoi cd in cell $name" >&2
      return 1
    fi
  done < <(each_named_cell)
}

# Runme is optional: a block pasted into a terminal must work as is. Input
# comes through `export VAR="<working default>"`, which Runme shows for
# confirmation and a reader can edit before pasting.
@test "named cells hold no placeholder: every value is a working default" {
  while IFS=$'\t' read -r name _; do
    bad=$(cell_body "$name" | grep -E '<[^>]+>' || true)
    [ -z "$bad" ] || { echo "placeholder in $name: $bad" >&2; return 1; }
  done < <(each_named_cell)
}

# Adding a file chezmoi already manages replaces its source, so accepting the
# default of a `chezmoi add` cell would overwrite a template with its output.
@test "chezmoi add cells default to a file the repo does not manage" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" "{\"modules\":$(all_modules_json)}"
  managed=$(chezmoi_managed "$H" --include=files --path-style=absolute)
  # A wrong flag or an empty render would make every target look unmanaged.
  printf '%s\n' "$managed" | grep -qxF "$H/.config/fish/config.fish"
  checked=0
  while IFS=$'\t' read -r name _; do
    body=$(cell_body "$name")
    printf '%s\n' "$body" | grep -qE '^chezmoi add ' || continue
    # shellcheck disable=SC2016 # matches a literal $HOME in the cell
    target=$(printf '%s\n' "$body" | sed -nE 's|^export FILE="\$HOME/(.*)"$|\1|p')
    [ -n "$target" ] || { echo "no FILE default under \$HOME in $name" >&2; return 1; }
    if printf '%s\n' "$managed" | grep -qxF "$H/$target"; then
      echo "$name defaults to a managed file: ~/$target" >&2
      return 1
    fi
    checked=$((checked + 1))
  done < <(each_named_cell)
  [ "$checked" -gt 0 ]
}

# Runme's own parser is the reference for the annotations. Per-file mode
# (--filename) because project mode reads the git config, and go-git rejects
# the negative fetch refspec jj-stack adds to it.
runme_cells() {
  for f in README.md CHEATSHEET.md; do
    runme list --chdir "$REPO_ROOT" --filename "$f" --json
  done | jq -s 'add'
}

@test "runme lists exactly the named cells, with run --all following excludeFromRunAll" {
  command -v runme > /dev/null || skip "runme not on PATH"
  cells=$(runme_cells)
  # An ignored block is not listed; anything unnamed that is listed was missed.
  unnamed=$(printf '%s' "$cells" | jq -r '.[] | select(.named | not) | .name')
  [ -z "$unnamed" ] || { echo "runme lists unnamed cells: $unnamed" >&2; return 1; }
  diff <(printf '%s' "$cells" | jq -r '.[].name' | sort) \
    <(annotations | jq -r '.name // empty' | sort)
  # excludeFromRunAll is the string "true", which runme must read as a boolean.
  diff <(printf '%s' "$cells" | jq -r '.[] | select(.run_all) | .name' | sort) \
    <(annotations | jq -r 'select(.name and .excludeFromRunAll != "true") | .name' | sort)
}

# --dry-run prints only the first selected cell, so the tagged cells run for
# real against a chezmoi stub that records its arguments.
@test "runme run -t check runs exactly the cells tagged check" {
  command -v runme > /dev/null || skip "runme not on PATH"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  log="$BATS_TEST_TMPDIR/chezmoi.log"
  printf '#!/bin/sh\necho "chezmoi $*" >> "%s"\n' "$log" > "$BATS_TEST_TMPDIR/bin/chezmoi"
  chmod +x "$BATS_TEST_TMPDIR/bin/chezmoi"
  for f in README.md CHEATSHEET.md; do
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" HOME="$BATS_TEST_TMPDIR" \
      runme run --chdir "$REPO_ROOT" --filename "$f" --direnv=false --load-env=false -t check
  done
  expected=$(annotations | jq -r 'select(.tag // "" | split(",") | index("check")) | .name' \
    | while read -r n; do cell_body "$n"; done | grep -E '^chezmoi ')
  [ -n "$expected" ]
  diff <(sort "$log") <(printf '%s\n' "$expected" | sort)
}

@test "the README says Runme is optional and the blocks can be pasted" {
  intro=$(awk '/^## Using chezmoi/{on=1; next} /^## /{on=0} on' "$REPO_ROOT/README.md")
  printf '%s\n' "$intro" | grep -qiF 'optional'
  printf '%s\n' "$intro" | grep -qiE 'paste|copy'
}

@test "the cheatsheet explains how to run the cells, and the README links to it" {
  grep -qF 'runme run' "$REPO_ROOT/CHEATSHEET.md"
  grep -qF 'runme list' "$REPO_ROOT/CHEATSHEET.md"
  grep -qF '(CHEATSHEET.md#run-these-steps-with-runme)' "$REPO_ROOT/README.md"
}

@test "runme is an optional module, not a core package, and not selected by default" {
  yq -r '.packages.darwin.modules.runme.brews[]' "$REPO_ROOT/.chezmoidata/packages.yaml" | grep -qxF runme
  if yq -r '.packages.darwin.core.brews[]' "$REPO_ROOT/.chezmoidata/packages.yaml" | grep -qxF runme; then
    echo "runme is a core package" >&2
    return 1
  fi
  grep -qF '"runme | ' "$REPO_ROOT/.chezmoi.toml.tmpl"
  # shellcheck disable=SC2016 # matches a literal $defaults in the template
  if grep -E '^# \[\[ \$defaults := ' "$REPO_ROOT/.chezmoi.toml.tmpl" | grep -qF '"runme"'; then
    echo "runme is selected by default" >&2
    return 1
  fi
}
