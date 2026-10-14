#!/usr/bin/env bats
# Node.js LTS comes from fnm on both systems: Homebrew on macOS, a chezmoi
# external on Linux, and one shared script that installs the LTS and makes it the
# default. nvm is a bash function that fish cannot run, so nothing installs it.

setup() {
  load 'helpers/setup'
  SCRIPT="$REPO_ROOT/.chezmoiscripts/run_onchange_after_install-node.sh"
}

@test "no install script, external, package list or fish config mentions nvm" {
  if grep -rniw 'nvm' "$REPO_ROOT/.chezmoiscripts" "$REPO_ROOT/.chezmoiexternal.toml.tmpl" \
    "$REPO_ROOT/.chezmoidata" "$REPO_ROOT/dot_config/fish"; then
    return 1
  fi
}

@test "the old Linux-only nvm script is gone and the shared script is executable" {
  [ ! -e "$REPO_ROOT/.chezmoiscripts/linux/run_onchange_10_install-node.sh" ]
  [ -x "$SCRIPT" ]
}

@test "fnm is in the macOS core brews and rendered once" {
  yq -e '.packages.darwin.core.brews | contains(["fnm"])' "$REPO_ROOT/.chezmoidata/packages.yaml" > /dev/null
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  [ "$(printf '%s\n' "$rendered" | grep -cxF 'brew "fnm"')" = "1" ]
}

@test "the script installs the LTS, makes it the default, and uses fnm from ~/.local/bin" {
  H="$BATS_TEST_TMPDIR/home"
  mkdir -p "$H/.local/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  : > "$CALLS"
  printf '#!/bin/sh\necho "fnm $*" >> "%s"\necho "v22.0.0"\n' "$CALLS" > "$H/.local/bin/fnm"
  chmod +x "$H/.local/bin/fnm"
  run env -i HOME="$H" PATH="/usr/bin:/bin" sh "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx 'fnm install --lts' "$CALLS"
  grep -qx 'fnm default lts-latest' "$CALLS"
}

@test "the script skips quietly when fnm is not installed" {
  H="$BATS_TEST_TMPDIR/home"
  mkdir -p "$H"
  run env -i HOME="$H" PATH="/usr/bin:/bin" sh "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fnm is not installed"* ]]
}

@test "the fish config loads fnm only when it is installed" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" dot_config/fish/config.fish.tmpl)
  line=$(printf '%s\n' "$rendered" | grep -n 'fnm env --use-on-cd --shell fish | source' | head -1 | cut -d: -f1)
  [ -n "$line" ]
  printf '%s\n' "$rendered" | sed -n "$((line - 1))p" | grep -qx 'if command -q fnm'
}
