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

@test "all core casks are rendered exactly once" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)

  expected_casks=$(yq -r '.packages.darwin.core.casks[]' "$REPO_ROOT/.chezmoidata/packages.yaml")

  while IFS= read -r cask; do
    [ -n "$cask" ] || continue
    [ "$(printf '%s\n' "$rendered" | grep -c "^cask \"$cask\"$")" = "1" ]
  done <<< "$expected_casks"
}

@test "per-module brews and casks render iff module selected" {
  modules=$(yq -r '.packages.darwin.modules | keys | .[]' "$REPO_ROOT/.chezmoidata/packages.yaml")

  while IFS= read -r module; do
    [ -n "$module" ] || continue

    H_off=$(mk_fake_home "$BATS_TEST_TMPDIR/off-$module")
    seed_chezmoi_config "$H_off" '{"modules":[]}'
    rendered_off=$(chezmoi_render "$H_off" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)

    H_on=$(mk_fake_home "$BATS_TEST_TMPDIR/on-$module")
    seed_chezmoi_config "$H_on" "$(jq -nc --arg m "$module" '{modules:[$m]}')"
    rendered_on=$(chezmoi_render "$H_on" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)

    brews=$(yq -r ".packages.darwin.modules.${module}.brews // [] | .[]" "$REPO_ROOT/.chezmoidata/packages.yaml")
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if printf '%s\n' "$rendered_off" | grep -qxF "brew \"$b\""; then
        echo "Module '$module' brew '$b' rendered when module disabled" >&2
        return 1
      fi
      if [ "$(printf '%s\n' "$rendered_on" | grep -c "^brew \"$b\"$")" != "1" ]; then
        echo "Module '$module' brew '$b' missing or duplicated when enabled" >&2
        return 1
      fi
    done <<< "$brews"

    casks=$(yq -r ".packages.darwin.modules.${module}.casks // [] | .[]" "$REPO_ROOT/.chezmoidata/packages.yaml")
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      if printf '%s\n' "$rendered_off" | grep -qxF "cask \"$c\""; then
        echo "Module '$module' cask '$c' rendered when module disabled" >&2
        return 1
      fi
      if [ "$(printf '%s\n' "$rendered_on" | grep -c "^cask \"$c\"$")" != "1" ]; then
        echo "Module '$module' cask '$c' missing or duplicated when enabled" >&2
        return 1
      fi
    done <<< "$casks"
  done <<< "$modules"
}
