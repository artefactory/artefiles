#!/usr/bin/env bash
# Hermetic-test helpers. Sourced from each .bats file's setup().
#
# Tests must NEVER touch the real $HOME. Every helper writes inside
# $BATS_TEST_TMPDIR (auto-cleaned per test).

# REPO_ROOT — absolute path to the artefiles checkout under test.
# Resolved once, exported so child processes (chezmoi) inherit it.
export REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# mk_fake_home — create an isolated $HOME for this test, echo its path.
# Subsequent chezmoi calls take --destination "$H".
mk_fake_home() {
  local h="${1:-$BATS_TEST_TMPDIR/h}"
  mkdir -p "$h/.config/chezmoi"
  printf '%s\n' "$h"
}

# seed_chezmoi_config H DATA_JSON
#   H         — fake-home path returned by mk_fake_home
#   DATA_JSON — JSON object with .data fields, e.g. '{"modules":["aerospace"]}'
#
# Writes a minimal chezmoi.toml so `chezmoi apply` skips init/prompts.
# Required fields (name, email) are filled with stubs unless DATA_JSON
# overrides them. modules defaults to [] so per-module gates evaluate false.
seed_chezmoi_config() {
  local h="$1" data="${2:-{\}}"
  local cfg="$h/.config/chezmoi/chezmoi.toml"
  local name email modules
  name=$(printf '%s' "$data" | jq -r '.name // "test-user"')
  email=$(printf '%s' "$data" | jq -r '.email // "test@example.com"')
  modules=$(printf '%s' "$data" | jq -c '.modules // []')
  cat >"$cfg" <<EOF
sourceDir = "$REPO_ROOT"

[data]
name = "$name"
email = "$email"
credentialHelper = "cache"
modules = $modules
EOF
}

# Run chezmoi against fake-home H, passing --config explicitly so XDG_CONFIG_HOME
# (set on Linux runners) can't pull a different config from under us. Also clear
# XDG_CONFIG_HOME for the same reason.
# --exclude=scripts,externals: skip run_*/before_*/after_* scripts AND remote
# external dependencies (chezmoiexternal). Tests target file rendering and
# ignore-rule logic; script and external-deps behavior is out of scope here.
_chezmoi() {
  local h="$1" sub="$2"; shift 2
  XDG_CONFIG_HOME="$h/.config" HOME="$h" chezmoi "$sub" \
    --config "$h/.config/chezmoi/chezmoi.toml" \
    --destination "$h" --source "$REPO_ROOT" \
    --exclude=scripts,externals "$@"
}

chezmoi_apply()   { _chezmoi "$1" apply   "${@:2}"; }
chezmoi_diff()    { _chezmoi "$1" diff    "${@:2}"; }
chezmoi_managed() { _chezmoi "$1" managed "${@:2}"; }

# Like chezmoi_managed but includes scripts. Use when the test is checking
# script-gating behavior; otherwise prefer chezmoi_managed.
chezmoi_managed_with_scripts() {
  local h="$1"; shift
  XDG_CONFIG_HOME="$h/.config" HOME="$h" chezmoi managed \
    --config "$h/.config/chezmoi/chezmoi.toml" \
    --destination "$h" --source "$REPO_ROOT" \
    --exclude=externals "$@"
}

# Render a source file's template to stdout. The seeded config at H must
# already exist (call seed_chezmoi_config first).
chezmoi_render() {
  local h="$1" file="$2"
  XDG_CONFIG_HOME="$h/.config" HOME="$h" chezmoi execute-template \
    --config "$h/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$h" \
    <"$REPO_ROOT/$file"
}
