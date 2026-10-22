#!/usr/bin/env bats
# The artefiles Claude Code skill loads (front matter), names only repository
# files that exist, and stays in the repository: chezmoi does not install it.

setup() {
  load 'helpers/setup'
  SKILL_DIR="$REPO_ROOT/.claude/skills/artefiles"
  SKILL="$SKILL_DIR/SKILL.md"
}

@test "the skill has the front matter Claude Code reads" {
  [ "$(sed -n 1p "$SKILL")" = "---" ]
  sed -n '2,/^---$/p' "$SKILL" | grep -qx 'name: artefiles'
  sed -n '2,/^---$/p' "$SKILL" | grep -q '^description: .\{40,\}'
  # Strict YAML, as gh skill install parses it: a bare ": " in a value fails.
  sed -n '2,/^---$/p' "$SKILL" | sed '$d' | yq -e '.description | length > 40' > /dev/null
}

@test "every repository file the skill and its references name exists" {
  paths=$(cat "$SKILL" "$SKILL_DIR"/references/*.md | grep -oE '`[A-Za-z0-9_./-]+`' | tr -d '`' \
    | grep -E '^(\./)?([A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.(sh|tmpl|toml|yaml|bats|bash|md)$|^(tests|\.chezmoi[a-z]*|\.github)(/|$)' | sort -u)
  [ -n "$paths" ]
  for p in $paths; do
    # Files of a user's project, not of this repository.
    case "$p" in pyproject.toml | uv.lock | .pre-commit-config.yaml) continue ;; esac
    # A path is relative to the repository, or to the skill (references/...).
    [ -e "$REPO_ROOT/${p#./}" ] || [ -e "$SKILL_DIR/$p" ] || { echo "missing: $p"; false; }
  done
}

@test "every module has a reference that names each package it installs" {
  [ -f "$SKILL_DIR/references/core.md" ]
  for m in $(prompt_module_names); do
    ref="$SKILL_DIR/references/$m.md"
    [ -f "$ref" ] || { echo "no reference for $m" >&2; return 1; }
    for pkg in $(yq -r ".packages.darwin.modules.$m | ((.brews // []) + (.casks // []))[]" "$REPO_ROOT/.chezmoidata/packages.yaml"); do
      grep -qiF "${pkg##*/}" "$ref" || { echo "$ref does not name $pkg" >&2; return 1; }
    done
  done
}

@test "chezmoi does not install the skill into the home directory" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  run chezmoi_managed "$H"
  [ "$status" -eq 0 ]
  [[ "$output" != *".claude/skills"* ]]
}
