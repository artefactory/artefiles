#!/usr/bin/env bats
# .chezmoiexternal.toml.tmpl drives Linux external-tool installs. A typo or
# bad arch interpolation produces dead URLs. Verify the rendered output is
# valid TOML, has no empty interpolations, and includes every tool we expect.
#
# Rendering only calls api.github.com (gitHubLatestReleaseAssetURL); releases
# hosted elsewhere are pinned in .chezmoidata/versions.yaml.

setup() {
  load 'helpers/setup'
}

ALL_MODULES='["editor","ghostty","cmux","git_advanced","atuin","python_dev","gcloud","colima","terraform","opentofu","pre_commit","prek"]'

# Sets $rendered to .chezmoiexternal.toml.tmpl evaluated for home $1. The
# template is guarded by `eq .chezmoi.os "linux"` and renders empty elsewhere,
# so that guard is replaced to exercise the Linux branch on any OS. Without
# --init so that .chezmoidata (the pinned versions) is loaded, as in an apply.
render_externals() {
  local h="$1" err="$BATS_TEST_TMPDIR/render.err"
  if ! rendered=$(XDG_CONFIG_HOME="$h/.config" HOME="$h" chezmoi execute-template \
    --config "$h/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$h" \
    < <(sed 's/eq \.chezmoi\.os "linux"/true/' "$REPO_ROOT/.chezmoiexternal.toml.tmpl") 2> "$err"); then
    cat "$err" >&2
    return 1
  fi
  # Guard against a vacuous pass: the forced Linux branch must have rendered.
  printf '%s\n' "$rendered" | grep -qF '[".local/bin/starship"]'
}

@test "externals.toml renders to valid TOML on linux with all modules" {
  if ! command -v python3 > /dev/null 2>&1; then
    skip "python3 not available"
  fi
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" "{\"modules\":$ALL_MODULES}"

  render_externals "$H"

  printf '%s\n' "$rendered" | python3 -c '
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib
tomllib.loads(sys.stdin.read())
'
}

@test "externals.toml urls have no empty arch interpolations" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" "{\"modules\":$ALL_MODULES}"

  render_externals "$H"

  # Catch double-dashes or unresolved <...> placeholders that signal a
  # printf-with-empty-string bug.
  if printf '%s\n' "$rendered" | grep -E 'url = "[^"]*--unknown-' > /dev/null; then
    echo "Found dead arch interpolation in rendered URL:" >&2
    printf '%s\n' "$rendered" | grep -E 'url = "[^"]*--unknown-' >&2
    return 1
  fi
  if printf '%s\n' "$rendered" | grep -E 'url = "[^"]*<no value>' > /dev/null; then
    echo "Found <no value> in rendered URL:" >&2
    printf '%s\n' "$rendered" | grep -E 'url = "[^"]*<no value>' >&2
    return 1
  fi
}

@test "mergiraf is installed on linux with no modules, from the pinned tag" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'

  render_externals "$H"

  tag=$(yq -r '.versions.mergiraf' "$REPO_ROOT/.chezmoidata/versions.yaml")
  printf '%s\n' "$rendered" | grep -qF '[".local/bin/mergiraf"]'
  printf '%s\n' "$rendered" | grep -qF "/releases/download/${tag}/mergiraf_"
}

@test "jj is not installed by the linux externals" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" "{\"modules\":$ALL_MODULES}"

  render_externals "$H"

  if printf '%s\n' "$rendered" | grep -qF '".local/bin/jj"'; then return 1; fi
}
