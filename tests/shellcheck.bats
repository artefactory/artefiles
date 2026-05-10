#!/usr/bin/env bats
# Render every templated/plain shell script under .chezmoiscripts and run
# shellcheck against the rendered output. Catches SC1128 (shebang not on
# line 1), unquoted expansions, and other real shell bugs that escape eyes
# during review. Renders with all modules enabled so per-module gates emit.

setup() {
  load 'helpers/setup'
  if ! command -v shellcheck > /dev/null 2>&1; then
    skip "shellcheck not available"
  fi
}

_shellcheck_dir() {
  local dir="$1"
  H=$(mk_fake_home)
  all=$(yq -r '.packages.darwin.modules | keys | .[]' "$REPO_ROOT/.chezmoidata/packages.yaml" \
        | jq -R . | jq -sc .)
  seed_chezmoi_config "$H" "$(jq -nc --argjson m "$all" '{modules:$m}')"

  for f in "$REPO_ROOT"/$dir/*.sh "$REPO_ROOT"/$dir/*.sh.tmpl; do
    [ -f "$f" ] || continue
    rel=${f#"$REPO_ROOT"/}
    out="$BATS_TEST_TMPDIR/$(basename "${rel%.tmpl}")"
    if [[ "$f" == *.tmpl ]]; then
      chezmoi_render "$H" "$rel" > "$out"
    else
      cp "$f" "$out"
    fi
    if ! shellcheck -S error "$out" 2>"$BATS_TEST_TMPDIR/err"; then
      echo "shellcheck failed on rendered $rel:" >&2
      cat "$BATS_TEST_TMPDIR/err" >&2
      return 1
    fi
  done
}

@test "every linux install script shellchecks after rendering" {
  _shellcheck_dir .chezmoiscripts/linux
}

@test "every darwin install script shellchecks after rendering" {
  _shellcheck_dir .chezmoiscripts/darwin
}

@test "every cross-OS install script shellchecks after rendering" {
  _shellcheck_dir .chezmoiscripts
}
