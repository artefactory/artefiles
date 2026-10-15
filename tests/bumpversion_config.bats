#!/usr/bin/env bats
# .bumpversion.toml turns the v<YYYY>.<MM>.<PATCH> tags into the next CalVer release.
# A wrong answer either reissues a spent version or skips the month's counter, and the
# release workflow cannot undo a pushed tag. Skipped when bump-my-version is not
# installed: the suite never downloads tools.

setup() {
  load 'helpers/setup'
}

# The tests below need the tool; this one reads the file only. January to September are
# the months where {MM} and {0M} differ, and the date-based tests cannot run in them
# unless it is one of those months.
@test "the month is zero-padded so tags sort and 2026.09 is not 2026.9" {
  grep -qF 'calver_format = "{YYYY}.{0M}"' "$REPO_ROOT/.bumpversion.toml"
  grep -qF '(?:1[0-2]|0[1-9])' "$REPO_ROOT/.bumpversion.toml"
}

@test "the config is not managed by chezmoi" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  if chezmoi_managed "$H" | grep -Fx '.bumpversion.toml'; then return 1; fi
}

setup_repo() {
  command -v bump-my-version > /dev/null 2>&1 || skip "bump-my-version not available"
  R="$BATS_TEST_TMPDIR/repo"
  git init -q "$R"
  git -C "$R" config user.email t@example.org
  git -C "$R" config user.name t
  git -C "$R" config commit.gpgsign false
  git -C "$R" config tag.gpgsign false
  cp "$REPO_ROOT/.bumpversion.toml" "$R/"
  git -C "$R" commit -q --allow-empty -m "feat: first"
  MONTH=$(date +%Y.%m)
}

# release TAG — tag the current commit, then move on so HEAD is untagged again.
release() {
  git -C "$R" tag -a "$1" -m "$1"
  git -C "$R" commit -q --allow-empty -m "feat: after $1"
}

next() { (cd "$R" && bump-my-version show new_version --increment patch 2> /dev/null); }

@test "a later release in the same month adds one" {
  setup_repo
  release "v${MONTH}.0"
  [ "$(next)" = "${MONTH}.1" ]
}

@test "the counter is compared as a number, not as text" {
  setup_repo
  for n in 0 1 2 9 10; do release "v${MONTH}.$n"; done
  [ "$(next)" = "${MONTH}.11" ]
}

@test "a new month starts again at 0" {
  setup_repo
  release "v2020.01.7"
  [ "$(next)" = "${MONTH}.0" ]
}

@test "bump tags the commit with an annotated tag and writes no file" {
  setup_repo
  release "v2020.01.0"
  version=$(next)
  (cd "$R" && bump-my-version bump --new-version "$version" patch > /dev/null 2>&1)
  [ "$(git -C "$R" cat-file -t "v$version")" = tag ]
  [ "$(git -C "$R" describe --tags --exact-match HEAD)" = "v$version" ]
  [ -z "$(git -C "$R" status --porcelain | grep -v '^?? \.bumpversion\.toml$' || true)" ]
}
