#!/usr/bin/env bats
# A workflow that pins an action by commit hash stops starting when the action's owner
# deletes that commit, so every action is referenced by its version tag.

setup() {
  load 'helpers/setup'
}

@test "no workflow references an action by a commit hash" {
  if grep -rnE 'uses: +[^ ]+@[0-9a-f]{40}' "$REPO_ROOT/.github/workflows"; then
    echo "reference the version tag instead of the hash" >&2
    return 1
  fi
}

@test "every action is referenced with a version after the @" {
  while IFS= read -r line; do
    case "$line" in ./*) continue ;; esac
    [[ "$line" =~ @v[0-9] ]] || { echo "no version in: $line" >&2; return 1; }
  done < <(grep -rhoE 'uses: +[^ ]+' "$REPO_ROOT/.github/workflows" | sed -E 's/uses: +//')
}
