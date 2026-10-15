#!/usr/bin/env bats
# cliff.toml turns merged-PR commits into release notes. These tests render it over a
# small history so a template edit cannot silently drop breaking changes, issue links or
# the group order.

setup() {
  load 'helpers/setup'
  command -v git-cliff > /dev/null 2>&1 || skip "git-cliff not available"
  R="$BATS_TEST_TMPDIR/repo"
  git init -q "$R"
  git -C "$R" config user.email t@example.org
  git -C "$R" config user.name t
  git -C "$R" config commit.gpgsign false
  git -C "$R" config tag.gpgsign false
  commit 'fix(install): keep sudo alive'
  commit 'feat(modules): add shell_tools\n\nBody.\n\nCloses #175\nCloses #176'
  commit 'test(install): drive the checklist'
  commit 'chore(deps): bump something'
  commit 'feat(modules)!: rename colima to containers\n\nBREAKING CHANGE: colima is now containers; re-run chezmoi init.'
  commit 'not a conventional commit'
  git -C "$R" tag -a v2026.10.0 -m v2026.10.0
  commit 'fix: after the release'
}

# commit MESSAGE — an empty commit whose message may hold \n escapes.
commit() { printf '%b\n' "$1" | git -C "$R" commit -q --allow-empty -F -; }

render() { git -C "$R" cliff --config "$REPO_ROOT/cliff.toml" "$@" 2> /dev/null; }

@test "the config prints to stdout and never rewrites a file" {
  run render
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ ! -e "$R/CHANGELOG.md" ]
}

@test "breaking changes come first in their release, with the migration note" {
  run render
  rel=$(printf '%s\n' "$output" | awk '/^## \[2026\.10\.0\]/{f=1} f')
  [ "$(printf '%s\n' "$rel" | grep -n 'Breaking changes' | cut -d: -f1)" -lt "$(printf '%s\n' "$rel" | grep -n '### Features' | cut -d: -f1)" ]
  [[ "$rel" == *"colima is now containers; re-run chezmoi init."* ]]
}

@test "an entry links its commit and the issues it closes" {
  run render
  [[ "$output" == *"[#175](https://github.com/artefactory/artefiles/issues/175), [#176]("* ]]
  [[ "$output" == *"artefiles/commit/"* ]]
}

@test "tests, dependency bumps and non-conventional commits are left out" {
  run render
  [[ "$output" != *"drive the checklist"* ]]
  [[ "$output" != *"bump something"* ]]
  [[ "$output" != *"not a conventional commit"* ]]
}

@test "groups are ordered features before fixes, whatever their names sort to" {
  run render
  rel=$(printf '%s\n' "$output" | awk '/^## \[2026\.10\.0\]/{f=1} f')
  [ "$(printf '%s\n' "$rel" | grep -n '^### Features' | cut -d: -f1)" -lt "$(printf '%s\n' "$rel" | grep -n '^### Bug fixes' | cut -d: -f1)" ]
}

@test "commits since the last tag are listed as unreleased and a release links its diff" {
  run render
  [[ "$output" == *"## [Unreleased]"* ]]
  [[ "$output" == *"After the release"* ]]
  run render --tag v2026.11.0
  [[ "$output" == *"compare/v2026.10.0...v2026.11.0"* ]]
}
