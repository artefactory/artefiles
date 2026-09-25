#!/usr/bin/env bats
# .chezmoiexternal.toml.tmpl drives Linux external-tool installs. A typo or
# bad arch interpolation produces dead URLs. Verify the rendered output is
# valid TOML, has no empty interpolations, and includes every tool we expect.

setup() {
  load 'helpers/setup'
}

# Sets $rendered to .chezmoiexternal.toml.tmpl evaluated for home $1, forcing
# the linux template-eval path even on macOS runners. The template fetches
# release tags over the network at render time (codeberg has no token path
# like GITHUB_TOKEN), so a curl transport failure skips the test instead of
# failing it; any other render error still fails.
render_externals() {
  local h="$1" err="$BATS_TEST_TMPDIR/render.err"
  if ! rendered=$(XDG_CONFIG_HOME="$h/.config" HOME="$h" chezmoi execute-template \
    --config "$h/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$h" \
    --init \
    < "$REPO_ROOT/.chezmoiexternal.toml.tmpl" 2> "$err"); then
    if grep -qE 'curl: \((6|7|28|35|52|56)\)' "$err"; then
      skip "network unavailable: $(grep -m1 -E 'curl: \(' "$err")"
    fi
    cat "$err" >&2
    return 1
  fi
}

@test "externals.toml renders to valid TOML on linux with all modules" {
  if ! command -v python3 > /dev/null 2>&1; then
    skip "python3 not available"
  fi
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor","terminal","atuin","gcloud","colima","git_advanced","onepassword","multiplexer","python_dev","aerospace","agent_skills"]}'

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
  seed_chezmoi_config "$H" '{"modules":["editor","terminal","atuin","gcloud","colima","git_advanced","onepassword","multiplexer","python_dev","aerospace","agent_skills"]}'

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
