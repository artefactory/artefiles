#!/usr/bin/env bats
# `chezmoi update` runs the command set by `[update]` in the rendered config.
# On a release install the clone sits on a detached tag, where chezmoi's default
# `git pull --rebase` fails; the command must move it to the latest release, and
# must leave a clone on a branch (a fork on its own main) to a plain pull.
# Everything runs against local repositories: no network, no GitHub.

setup() {
  load 'helpers/setup'

  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/gh" << 'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$fake_bin/gh"

  H=$(mk_fake_home)
  rendered=$(env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi execute-template \
    --source "$REPO_ROOT" --destination "$H" \
    --init \
    --promptString "email=t@example.com" \
    --promptMultichoice "modules=editor" \
    < "$REPO_ROOT/.chezmoi.toml.tmpl")

  UPDATE_CMD=$(printf '%s\n' "$rendered" | python3 -c '
import sys, tomllib
print(tomllib.loads(sys.stdin.read())["update"]["command"])')
  UPDATE_SCRIPT=$(printf '%s\n' "$rendered" | python3 -c '
import sys, tomllib
print(tomllib.loads(sys.stdin.read())["update"]["args"][1])')

  # The developer's own git settings (signing, hooks, tag.annotate) must not
  # leak into the fixture repositories.
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
  git config --file "$GIT_CONFIG_GLOBAL" user.email t@example.com
  git config --file "$GIT_CONFIG_GLOBAL" user.name t

  origin="$BATS_TEST_TMPDIR/origin.git"
  seed="$BATS_TEST_TMPDIR/seed"
  work="$BATS_TEST_TMPDIR/work"
  git init --quiet --bare --initial-branch=main "$origin"
  git init --quiet --initial-branch=main "$seed"
  git -C "$seed" remote add origin "$origin"
  echo one > "$seed/f"
  git -C "$seed" add f
  git -C "$seed" commit --quiet -m one
  git -C "$seed" tag v2026.10.1
  echo two > "$seed/f"
  git -C "$seed" commit --quiet -am two
  git -C "$seed" tag v2026.10.2
  git -C "$seed" push --quiet origin main --tags
}

# Run the rendered update command in the clone, as chezmoi does.
run_update() {
  cd "$work"
  run "$UPDATE_CMD" -c "$UPDATE_SCRIPT"
}

@test "the rendered config sets the update command" {
  [ "$UPDATE_CMD" = "sh" ]
  [ -n "$UPDATE_SCRIPT" ]
}

@test "a clone detached at an older release moves to the latest release" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.1
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse v2026.10.2)" ]
}

@test "a release published after the install is picked up" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.2
  echo three > "$seed/f"
  git -C "$seed" commit --quiet -am three
  git -C "$seed" tag v2026.10.10
  git -C "$seed" push --quiet origin main --tags
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse v2026.10.10)" ]
}

@test "a clone already at the latest release says so and exits 0" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.2
  before=$(git -C "$work" rev-parse HEAD)
  run_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"already at v2026.10.2"* ]]
  [ "$(git -C "$work" rev-parse HEAD)" = "$before" ]
}

@test "a clone on a branch pulls its own remote and stays on the branch" {
  git clone --quiet "$origin" "$work"
  echo three > "$seed/f"
  git -C "$seed" commit --quiet -am three
  git -C "$seed" push --quiet origin main
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" symbolic-ref --short HEAD)" = "main" ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ]
}

@test "a fork with its own tags updates from its own origin" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.1
  echo fork > "$seed/f"
  git -C "$seed" commit --quiet -am fork
  git -C "$seed" tag v2026.11.1
  git -C "$seed" push --quiet origin main --tags
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse v2026.11.1)" ]
}

@test "a detached clone that is not on a release stops with guidance" {
  git clone --quiet "$origin" "$work"
  echo more > "$seed/f"
  git -C "$seed" commit --quiet -am more
  git -C "$seed" push --quiet origin main
  git -C "$work" fetch --quiet origin
  git -C "$work" checkout --quiet --detach origin/main
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"not on a branch or a release tag"* ]]
  [[ "$output" == *"switch <branch>"* ]]
}

@test "local changes stop the move to the new release with a message" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.1
  echo dirty > "$work/f"
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"Could not check out"* ]]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse v2026.10.1)" ]
}

@test "chezmoi update itself moves a tag install to the latest release" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.1
  cfg="$H/.config/chezmoi/chezmoi.toml"
  mkdir -p "$(dirname "$cfg")"
  printf '%s\n' "$rendered" | sed "s|^sourceDir = .*|sourceDir = \"$work\"|" > "$cfg"
  run env HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    chezmoi update --apply=false --config "$cfg" --source "$work" --destination "$H"
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse v2026.10.2)" ]
}

@test "a clone on a tag that is not a release stops with a way out" {
  git clone --quiet "$origin" "$work"
  git -C "$seed" tag stable v2026.10.1
  git -C "$seed" push --quiet origin stable
  git -C "$work" fetch --quiet --tags origin
  git -C "$work" checkout --quiet --detach stable
  git -C "$work" tag -d v2026.10.1 > /dev/null
  before=$(git -C "$work" rev-parse HEAD)
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"not on a branch or a release tag"* ]]
  [[ "$output" == *"switch <branch>"* ]]
  [ "$(git -C "$work" rev-parse HEAD)" = "$before" ]
}

@test "a clone pinned to a branch by the installer follows that branch on update" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.1
  echo three > "$seed/f"
  git -C "$seed" commit --quiet -am three
  git -C "$seed" push --quiet origin main
  # The installer's own checkout_ref, as a rerun with ARTEFILES_VERSION=main runs it.
  sed -n '/^checkout_ref()/,/^}/p' "$REPO_ROOT/install.sh" > "$BATS_TEST_TMPDIR/checkout_ref.sh"
  (ref=main && . "$BATS_TEST_TMPDIR/checkout_ref.sh" && checkout_ref "$work")
  echo four > "$seed/f"
  git -C "$seed" commit --quiet -am four
  git -C "$seed" push --quiet origin main
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" symbolic-ref --short HEAD)" = "main" ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ]
}

@test "a branch update keeps uncommitted edits made in the source" {
  git clone --quiet "$origin" "$work"
  echo three > "$seed/f"
  git -C "$seed" commit --quiet -am three
  git -C "$seed" push --quiet origin main
  echo edit > "$work/mine"
  git -C "$work" add mine
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ]
  [ "$(cat "$work/mine")" = edit ]
}

@test "a branch update rebases local commits instead of merging" {
  git clone --quiet "$origin" "$work"
  echo mine > "$work/mine"
  git -C "$work" add mine
  git -C "$work" commit --quiet -m mine
  echo three > "$seed/f"
  git -C "$seed" commit --quiet -am three
  git -C "$seed" push --quiet origin main
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" rev-parse HEAD^)" = "$(git -C "$seed" rev-parse HEAD)" ]
  [ -z "$(git -C "$work" rev-list --merges HEAD)" ]
}

@test "a tag that is not a release is never taken as the latest release" {
  git clone --quiet "$origin" "$work"
  git -C "$work" checkout --quiet --detach v2026.10.1
  echo three > "$seed/f"
  git -C "$seed" commit --quiet -am three
  git -C "$seed" tag w-test
  git -C "$seed" push --quiet origin main --tags
  run_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$seed" rev-parse v2026.10.2)" ]
}
