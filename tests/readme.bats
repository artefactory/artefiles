#!/usr/bin/env bats
# Regression tests for README accuracy — paths, language, and links.
# Enforces acceptance criteria from issue #71.

setup() {
  load 'helpers/setup'
}

@test "all listed config paths materialize after chezmoi apply" {
  # Verify every ~/. path mentioned in the README is actually managed
  # by chezmoi on this OS. Source-name agnostic: doesn't matter whether
  # the source uses dot_, private_dot_, create_, .tmpl, etc. — only
  # that `chezmoi managed` exposes the target.
  H=$(mk_fake_home)
  modules=$(awk '/^    modules:$/,/^[^ ]/{ if ($0 ~ /^      [a-z_]+:$/) { sub(":",""); gsub(" ",""); print } }' \
            "$REPO_ROOT/.chezmoidata/packages.yaml" | jq -R . | jq -sc .)
  seed_chezmoi_config "$H" "{\"modules\":$modules}"
  managed=$(chezmoi_managed "$H")

  # README marks OS-specific paths inline as *(Linux)* or *(macOS)*.
  # Skip paths tagged for the other OS so each runner only validates
  # what its own chezmoi will materialize.
  case "$(uname)" in Darwin) other='*(Linux)*' ;; Linux) other='*(macOS)*' ;; *) other='__none__' ;; esac

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    # Skip a path if the README line containing it is tagged for the other OS.
    if grep -F "$p" "$REPO_ROOT/README.md" | grep -qF "$other"; then
      continue
    fi
    rel="${p#'~/'}"  # quoted so bash doesn't tilde-expand the pattern
    if ! printf '%s\n' "$managed" | grep -qxF "$rel"; then
      printf 'README lists path not managed by chezmoi: %s\n' "$p" >&2
      return 1
    fi
  done < <(grep -oE '~/[.][a-zA-Z0-9_./-]+' "$REPO_ROOT/README.md" \
           | grep -v '/$' | sort -u)
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
