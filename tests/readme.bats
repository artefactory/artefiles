#!/usr/bin/env bats
# Regression tests for README accuracy — paths, language, and links.
# Enforces acceptance criteria from issue #71.

setup() {
  load 'helpers/setup'
}

@test "all listed config paths exist in source" {
  # Extract ~/. paths mentioned in the README and verify each exists in source.
  # Handles chezmoi source naming variants: direct, .tmpl suffix, private_ prefix.
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    # Convert chezmoi target path to source path:
    # ~/.<name> → dot_<name>, e.g. ~/.config/fish/config.fish → dot_config/fish/config.fish
    src=$(printf '%s\n' "$p" | sed 's|~/\.||')
    src="dot_${src}"
    dir=$(dirname "$REPO_ROOT/$src")
    name=$(basename "$src")
    # Accept: direct, .tmpl suffix, private_ prefix, or private_+.tmpl variants.
    if ! test -e "$REPO_ROOT/$src" && \
       ! test -e "$REPO_ROOT/${src}.tmpl" && \
       ! test -e "$dir/private_${name}" && \
       ! test -e "$dir/private_${name}.tmpl"; then
      printf 'README lists path not found in source: %s\n' "$p" >&2
      return 1
    fi
  done < <(grep -oE '~/\.config/[a-zA-Z0-9_./-]+|~/\.[a-z_]+' "$REPO_ROOT/README.md" | sort -u)
}

@test "old prereq language is gone" {
  if grep -q 'brew install gh' "$REPO_ROOT/README.md"; then
    printf "README still contains 'brew install gh' (see #71)\n" >&2
    return 1
  fi
  if grep -q 'gh auth login' "$REPO_ROOT/README.md"; then
    printf "README still contains 'gh auth login' (see #71)\n" >&2
    return 1
  fi
}

@test "links resolve" {
  if ! command -v npx > /dev/null 2>&1; then
    skip "npx not available — install Node.js to run link-check"
  fi
  npx --yes markdown-link-check "$REPO_ROOT/README.md"
}
