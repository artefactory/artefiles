#!/usr/bin/env bats
# The release workflows run tools through uvx. Their versions live in one env variable
# each (not inside the command lines), and the two workflows that run git-cliff must
# pin the same one, or the PR preview would show notes the release does not publish.

setup() {
  load 'helpers/setup'
  RELEASE="$REPO_ROOT/.github/workflows/release.yaml"
  PREVIEW="$REPO_ROOT/.github/workflows/changelog-preview.yaml"
}

# pin FILE NAME — the value of the workflow-level env variable NAME.
pin() { sed -nE "s/^  $2: \"([^\"]+)\"$/\\1/p" "$1"; }

@test "every uvx call takes its version from an env variable" {
  for f in "$RELEASE" "$PREVIEW"; do
    if grep -nE 'uvx +"?[A-Za-z_-]+@[0-9]' "$f"; then echo "$f hardcodes a tool version in a command" >&2; return 1; fi
    grep -qE 'uvx +"[a-z-]+@\$\{[A-Z_]+\}"' "$f"
  done
}

@test "each tool version is pinned once per workflow, as a number" {
  [[ "$(pin "$RELEASE" BUMP_MY_VERSION_VERSION)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  [[ "$(pin "$RELEASE" GIT_CLIFF_VERSION)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  [[ "$(pin "$PREVIEW" GIT_CLIFF_VERSION)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "the preview and the release pin the same git-cliff" {
  [ "$(pin "$RELEASE" GIT_CLIFF_VERSION)" = "$(pin "$PREVIEW" GIT_CLIFF_VERSION)" ]
}

@test "the release tagger is the triggering account, not a hardcoded identity" {
  if grep -nE '[0-9]+\+[^"$ ]+@users\.noreply' "$RELEASE"; then return 1; fi
  grep -qF 'github.actor_id' "$RELEASE"
}
