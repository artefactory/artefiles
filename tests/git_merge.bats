#!/usr/bin/env bats
# git and mergiraf are core: every install gets a working merge driver, and
# jj (not used by the team) is gone.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

@test "mergiraf is a core brew, not a module brew" {
  yq -e '.packages.darwin.core.brews | contains(["mergiraf"])' "$REPO_ROOT/.chezmoidata/packages.yaml"
  ! yq -e '[.packages.darwin.modules[].brews[]] | contains(["mergiraf"])' "$REPO_ROOT/.chezmoidata/packages.yaml"
}

@test "jj is not installed by any package list" {
  ! grep -nE "^\s*- 'jj'" "$REPO_ROOT/.chezmoidata/packages.yaml"
}

@test "gitconfig defines the mergiraf driver with no modules selected" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" dot_gitconfig.tmpl)

  printf '%s\n' "$rendered" | grep -qF '[merge "mergiraf"]'
  printf '%s\n' "$rendered" | grep -qE '^\s*driver = mergiraf merge --git '
  printf '%s\n' "$rendered" | grep -qE '^\s*conflictstyle = diff3'
}

# A merge=mergiraf attribute without a defined driver makes every `git merge`
# fail with "custom merge driver mergiraf lacks command line".
@test "merge=mergiraf attribute and driver definition are never split" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"

  assert_file_exists "$H/.gitattributes_global"
  grep -qF 'merge=mergiraf' "$H/.gitattributes_global"
  grep -qF '[merge "mergiraf"]' "$H/.gitconfig"
}

@test "git merge auto-resolves a JSON conflict using the applied config" {
  command -v mergiraf > /dev/null 2>&1 || skip "mergiraf not installed"
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H"

  repo="$BATS_TEST_TMPDIR/repo"
  export HOME="$H" GIT_CONFIG_GLOBAL="$H/.gitconfig" GIT_CONFIG_SYSTEM=/dev/null
  git config --global user.name test
  git config --global user.email test@example.com
  git init -q "$repo"
  cd "$repo"
  printf '{\n  "a": 1,\n  "b": 2\n}\n' > c.json
  git add c.json && git commit -qm base
  git checkout -qb left
  printf '{\n  "a": 1,\n  "b": 2,\n  "l": 3\n}\n' > c.json
  git commit -qam left
  git checkout -q -
  git checkout -qb right
  printf '{\n  "a": 1,\n  "b": 2,\n  "r": 4\n}\n' > c.json
  git commit -qam right

  # The applied gitconfig sets merge.ff = only; --no-ff forces a real merge.
  git merge --no-ff -m merge left
  jq -e '.l == 3 and .r == 4' c.json
}

@test "mergiraf has one linux install path, the externals template" {
  if ls "$REPO_ROOT"/.chezmoiscripts/linux/*mergiraf* 2> /dev/null; then return 1; fi
  ! grep -n 'jj-vcs' "$REPO_ROOT/.chezmoiexternal.toml.tmpl"
}

@test "review fish function and completion do not reference jj" {
  ! grep -nw 'jj' \
    "$REPO_ROOT/dot_config/fish/functions/review.fish" \
    "$REPO_ROOT/dot_config/fish/completions/review.fish"
}

@test "README does not mention jj or Jujutsu" {
  ! grep -niE '\bjj\b|jujutsu' "$REPO_ROOT/README.md"
}

# Release tags are pinned in .chezmoidata/versions.yaml: resolving them at
# render time put codeberg.org on the path of every chezmoi command on Linux.
@test "mergiraf is pinned to a release tag in .chezmoidata/versions.yaml" {
  tag=$(yq -r '.versions.mergiraf' "$REPO_ROOT/.chezmoidata/versions.yaml")
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "the pinned versions reach the templates as .versions" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi data --format json \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    | jq -e '.versions.mergiraf | test("^v[0-9]+[.][0-9]+[.][0-9]+$")'
}

@test "the externals template makes no network call of its own at render time" {
  if grep -nE 'output "(curl|wget)"|httpGet' "$REPO_ROOT/.chezmoiexternal.toml.tmpl"; then return 1; fi
}

@test "the mergiraf external is built from the pinned tag" {
  grep -qF '.versions.mergiraf' "$REPO_ROOT/.chezmoiexternal.toml.tmpl"
}
