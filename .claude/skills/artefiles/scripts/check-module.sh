#!/bin/sh
# check-module.sh MODULE [SOURCE] — the places a module must appear in an
# artefiles checkout (SOURCE, default the chezmoi source). Exits 1 when a
# required one is missing; "-" marks places some modules rightly skip.
set -eu

m="${1:?usage: check-module.sh MODULE [SOURCE]}"
src="${2:-$(chezmoi source-path)}"
skill="$src/.claude/skills/artefiles"
missing=0

# shellcheck disable=SC2317,SC2329 # called through required/optional
has() { grep -qE "$2" "$src/$1" 2> /dev/null; }
required() {
  if "$@"; then echo "  ✓ $label"; else echo "  ✗ $label"; missing=1; fi
}
optional() {
  if "$@"; then echo "  ✓ $label"; else echo "  - $label"; fi
}

echo "$m:"
label="choice line in .chezmoi.toml.tmpl"
required has .chezmoi.toml.tmpl "append \\\$choices \"$m \\|"
label="row in README.md"
required has README.md "^\\| \`$m\` \\|"
label="guide .claude/skills/artefiles/references/$m.md"
required test -f "$skill/references/$m.md"
label="module count in tests/module_help.bats"
# shellcheck disable=SC2016 # the pattern matches a literal `$choices`
count=$(grep -cE '^# \[\[ \$choices = append' "$src/.chezmoi.toml.tmpl")
required has tests/module_help.bats "wc -l\\)\" -eq $count \\]"
label="macOS packages in .chezmoidata/packages.yaml"
optional has .chezmoidata/packages.yaml "^      $m:"
label="Linux download or script gated in .chezmoiexternal.toml.tmpl or .chezmoiignore"
optional sh -c "grep -qE 'has \"$m\"' '$src/.chezmoiexternal.toml.tmpl' '$src/.chezmoiignore'"
label="dotfiles_doctor check"
optional has dot_config/fish/functions/dotfiles_doctor.fish.tmpl "has \"$m\""
exit "$missing"
