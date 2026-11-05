#!/usr/bin/env bats
# The antigravity module installs Google Antigravity, the agent-first IDE, as
# the antigravity Homebrew cask. It is macOS-only like containers: offered on
# every OS, but nothing installs it on Linux. Not selected by default.

setup() {
  load 'helpers/setup'
}

PKG=.chezmoidata/packages.yaml
DARWIN_TMPL=.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl
REF=.claude/skills/artefiles/references/antigravity.md

# render MODULES_JSON FILE — FILE rendered for a home with these modules.
render() {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  chezmoi_render "$H" "$2"
}

@test "the init prompt offers antigravity, not checked by default" {
  prompt_module_names | grep -qx antigravity
  # shellcheck disable=SC2016 # the pattern matches a literal `$defaults`
  [ "$(grep -c '^# \[\[ \$defaults := list.*"antigravity"' "$REPO_ROOT/.chezmoi.toml.tmpl")" -eq 0 ]
  [[ "$(prompt_help antigravity)" == *"Antigravity on macOS"* ]]
}

@test "antigravity installs the antigravity cask on macOS, only when selected" {
  [ "$(yq -o=json -I=0 '.packages.darwin.modules.antigravity.casks' "$REPO_ROOT/$PKG")" = '["antigravity"]' ]
  [ "$(yq -r '.packages.darwin.modules.antigravity.brews | length' "$REPO_ROOT/$PKG")" -eq 0 ]
  render '["antigravity"]' "$DARWIN_TMPL" | grep -qxF 'cask "antigravity"'
  [ "$(render '[]' "$DARWIN_TMPL" | grep -c 'antigravity')" -eq 0 ]
  [ "$(render '["vscode"]' "$DARWIN_TMPL" | grep -c 'antigravity')" -eq 0 ]
}

# linux_render MODULES_JSON FILE — FILE rendered as on Linux; fails when the
# render fails, so an empty render never passes for an identical one.
linux_render() {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < <(sed -e 's/eq \.chezmoi\.os "linux"/true/' -e 's/eq \.chezmoi\.os "darwin"/false/' "$REPO_ROOT/$2")
}

@test "antigravity installs nothing on Linux: every Linux render is the same without it" {
  # Externals and ignores decide what a Linux apply manages; the cross-OS and
  # Linux scripts decide what it runs. The darwin scripts are ignored there.
  # The new-module offer is left out: it embeds the selection itself, for any
  # module, and installs nothing.
  files=(.chezmoiexternal.toml.tmpl .chezmoiignore)
  for f in "$REPO_ROOT"/.chezmoiscripts/*.tmpl "$REPO_ROOT"/.chezmoiscripts/linux/*.tmpl; do
    [ -f "$f" ] || continue
    [[ "$f" == */run_before_offer-new-modules.sh.tmpl ]] && continue
    files+=("${f#"$REPO_ROOT"/}")
  done
  for f in "${files[@]}"; do
    with=$(linux_render '["antigravity"]' "$f") || { echo "render failed: $f" >&2; return 1; }
    without=$(linux_render '[]' "$f") || { echo "render failed: $f" >&2; return 1; }
    [ -n "$without" ] || { echo "empty render: $f" >&2; return 1; }
    [ "$with" = "$without" ] || { echo "antigravity changes the Linux render of $f" >&2; return 1; }
  done
  # The sentinel proves the externals rendered for Linux at all.
  linux_render '["antigravity"]' .chezmoiexternal.toml.tmpl | grep -qF '[".local/bin/starship"]'
}

@test "the antigravity help and docs say it needs macOS 13 or later" {
  [[ "$(prompt_help antigravity)" == *"macOS 13+"* ]]
  grep -qF "| \`antigravity\` | $(prompt_help antigravity) | — |" "$REPO_ROOT/README.md"
  grep -qF "| \`antigravity\` | $(prompt_help antigravity) | [antigravity]($REF) |" "$REPO_ROOT/CHEATSHEET.md"
}

@test "antigravity has its README and cheatsheet rows and a reference" {
  grep -qE '^\| `antigravity` \| .* \| — \|$' "$REPO_ROOT/README.md"
  grep -qF '| `antigravity` |' "$REPO_ROOT/CHEATSHEET.md"
  grep -F '| `antigravity` |' "$REPO_ROOT/CHEATSHEET.md" | grep -qF "($REF)"
  [ -f "$REPO_ROOT/$REF" ]
  grep -qF 'antigravity' "$REPO_ROOT/$REF"
}
