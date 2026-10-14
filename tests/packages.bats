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

# every_qualified_package — "module owner/tap/name" for each brew or cask named
# through a third-party tap.
every_qualified_package() {
  yq -r '.packages.darwin.modules | to_entries[] | .key as $m | ((.value.brews // []) + (.value.casks // []))[] | select(test("^[^/]+/[^/]+/[^/]+$")) | $m + " " + .' \
    "$REPO_ROOT/.chezmoidata/packages.yaml"
}

@test "every package from a third-party tap has its tap declared in the same module" {
  [ -n "$(every_qualified_package)" ]
  while read -r module pkg; do
    tap="${pkg%/*}"
    yq -e ".packages.darwin.modules.$module.taps | contains([\"$tap\"])" "$REPO_ROOT/.chezmoidata/packages.yaml" > /dev/null \
      || { echo "$module: $pkg needs the tap $tap" >&2; return 1; }
  done < <(every_qualified_package)
}

@test "a selected module declares its tap before any package" {
  while read -r module pkg; do
    H=$(mk_fake_home "$BATS_TEST_TMPDIR/on-$module")
    seed_chezmoi_config "$H" "{\"modules\":[\"$module\"]}"
    rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
    tap_line=$(printf '%s\n' "$rendered" | grep -nxF "tap \"${pkg%/*}\"" | head -1 | cut -d: -f1)
    pkg_line=$(printf '%s\n' "$rendered" | grep -nE "^(brew|cask) \"$pkg\"$" | head -1 | cut -d: -f1)
    [ -n "$tap_line" ] && [ -n "$pkg_line" ] && [ "$tap_line" -lt "$pkg_line" ] \
      || { echo "$module: tap ${pkg%/*} is not declared before $pkg" >&2; return 1; }
  done < <(every_qualified_package)
}

@test "no tap is declared when no module needs one" {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/none")
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  if printf '%s\n' "$rendered" | grep -q '^tap '; then return 1; fi
}
