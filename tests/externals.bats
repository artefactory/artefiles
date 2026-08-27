#!/usr/bin/env bats
# .chezmoiexternal.toml.tmpl drives Linux external-tool installs. A typo or
# bad arch interpolation produces dead URLs. Verify the rendered output is
# valid TOML, has no empty interpolations, and includes every tool we expect.

setup() {
  load 'helpers/setup'
}

@test "externals.toml renders to valid TOML on linux with all modules" {
  if ! command -v python3 > /dev/null 2>&1; then
    skip "python3 not available"
  fi
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor","terminal","atuin","gcloud","colima","git_advanced","onepassword","multiplexer","python_dev","aerospace","agent_skills"]}'

  # Force linux template-eval path even on macOS runners.
  rendered=$(XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$H" \
    --init \
    < "$REPO_ROOT/.chezmoiexternal.toml.tmpl")

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

  rendered=$(XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$H" \
    --init \
    < "$REPO_ROOT/.chezmoiexternal.toml.tmpl")

  # Catch double-dashes or unresolved <...> placeholders that signal a
  # printf-with-empty-string bug.
  if printf '%s\n' "$rendered" | grep -E 'url = "[^"]*--unknown-' >/dev/null; then
    echo "Found dead arch interpolation in rendered URL:" >&2
    printf '%s\n' "$rendered" | grep -E 'url = "[^"]*--unknown-' >&2
    return 1
  fi
  if printf '%s\n' "$rendered" | grep -E 'url = "[^"]*<no value>' >/dev/null; then
    echo "Found <no value> in rendered URL:" >&2
    printf '%s\n' "$rendered" | grep -E 'url = "[^"]*<no value>' >&2
    return 1
  fi
}
