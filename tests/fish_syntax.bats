#!/usr/bin/env bats
# Parse-check fish config and functions so a stray syntax error in a
# templated config or autoloaded function is caught before it lands.

setup() {
  load 'helpers/setup'
  if ! command -v fish > /dev/null 2>&1; then
    skip "fish not available"
  fi
}

# Render a template through chezmoi, write to a temp file, fish -n it.
_check_template() {
  local h="$1" src="$2"
  local out="$BATS_TEST_TMPDIR/$(basename "${src%.tmpl}")"
  chezmoi_render "$h" "$src" > "$out"
  fish -n "$out"
}

@test "config.fish.tmpl parses with no modules" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  _check_template "$H" dot_config/fish/config.fish.tmpl
}

@test "config.fish.tmpl parses with all modules" {
  H=$(mk_fake_home)
  all=$(yq -r '.packages.darwin.modules | keys | .[]' "$REPO_ROOT/.chezmoidata/packages.yaml" \
        | jq -R . | jq -sc .)
  seed_chezmoi_config "$H" "$(jq -nc --argjson m "$all" '{modules:$m}')"
  _check_template "$H" dot_config/fish/config.fish.tmpl
}

@test "aliases.fish.tmpl parses" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  _check_template "$H" dot_config/fish/aliases.fish.tmpl
}

@test "private_artefiles_abbrs.fish parses" {
  fish -n "$REPO_ROOT/dot_config/fish/conf.d/private_artefiles_abbrs.fish"
}

@test "all autoloaded fish functions parse" {
  for f in "$REPO_ROOT"/dot_config/fish/functions/*.fish; do
    fish -n "$f"
  done
}
