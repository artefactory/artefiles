#!/usr/bin/env bats

setup() {
  load 'helpers/setup'
}

@test "all core brews are rendered exactly once" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)

  expected_brews=$(yq -r '.packages.darwin.core.brews[]' "$REPO_ROOT/.chezmoidata/packages.yaml")

  while IFS= read -r brew; do
    [ -n "$brew" ] || continue
    [ "$(printf '%s\n' "$rendered" | grep -c "^brew \"$brew\"$")" = "1" ]
  done <<< "$expected_brews"
}
