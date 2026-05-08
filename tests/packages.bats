#!/usr/bin/env bats

setup() {
  load 'helpers/setup'
}

@test "gh is in core brews" {
  yq -e '.packages.darwin.core.brews | index("gh") != null' \
    "$REPO_ROOT/.chezmoidata/packages.yaml"
}

@test "rendered Brewfile contains gh exactly once" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  [ "$(printf '%s\n' "$rendered" | grep -c '^brew "gh"$')" = "1" ]
}
