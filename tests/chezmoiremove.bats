#!/usr/bin/env bats
# .chezmoiremove takes the files artefiles no longer installs off existing
# installs, and keeps a file the user wrote at the same path.

setup() {
  load 'helpers/setup'
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["shell_tools","atuin"]}'
}

# put TARGET LINE... — write a file in the fake home.
put() {
  mkdir -p "$(dirname "$H/$1")"
  printf '%s\n' "${@:2}" > "$H/$1"
}

@test "the files earlier releases installed are removed by chezmoi apply" {
  put .config/direnv/direnvrc '#!/bin/bash' '# ~/.config/direnv/direnvrc' '# Support for uv (Python environment manager)' 'layout_uv() {' '}'
  put .config/fish/conf.d/direnv.fish "# Shadows homebrew's vendor_conf.d/direnv.fish, which runs \`direnv hook fish |"
  put .config/fish/functions/__cached_init.fish 'function __cached_init --argument-names key' 'end'
  put .config/fish/theme_preference 'Catppuccin Mocha'
  for key in direnv fzf atuin atuin-completions; do put ".cache/fish/init-$key.fish" 'set -g x 1'; done
  run chezmoi_apply "$H" --no-tty
  [ "$status" -eq 0 ]
  for f in .config/direnv/direnvrc .config/fish/conf.d/direnv.fish .config/fish/functions/__cached_init.fish \
    .config/fish/theme_preference .cache/fish/init-direnv.fish .cache/fish/init-fzf.fish \
    .cache/fish/init-atuin.fish .cache/fish/init-atuin-completions.fish; do
    [ ! -e "$H/$f" ] || { echo "still there: $f"; false; }
  done
}

@test "a file the user wrote at a retired path is kept" {
  put .config/direnv/direnvrc 'use_nix() { :; }'
  put .config/fish/conf.d/direnv.fish 'direnv hook fish | source'
  run chezmoi_apply "$H" --no-tty
  [ "$status" -eq 0 ]
  grep -qx 'use_nix() { :; }' "$H/.config/direnv/direnvrc"
  grep -qx 'direnv hook fish | source' "$H/.config/fish/conf.d/direnv.fish"
}

# The two files fish 4.3 writes on upgrade, as __fish_theme_migrate writes them.
@test "fish's upgrade files go, except key bindings the user changed" {
  put .config/fish/conf.d/fish_frozen_theme.fish \
    '# This file was created by fish when upgrading to version 4.3, to migrate' \
    '# theme variables from universal to global scope.' \
    'set --global fish_color_command FF0000'
  put .config/fish/conf.d/fish_frozen_key_bindings.fish \
    '# This file was created by fish when upgrading to version >= 4.3, to migrate' \
    '# set --global fish_key_bindings fish_default_key_bindings'
  run chezmoi_apply "$H" --no-tty
  [ "$status" -eq 0 ]
  [ ! -e "$H/.config/fish/conf.d/fish_frozen_theme.fish" ]
  [ ! -e "$H/.config/fish/conf.d/fish_frozen_key_bindings.fish" ]

  put .config/fish/conf.d/fish_frozen_key_bindings.fish \
    '# This file was created by fish when upgrading to version >= 4.3, to migrate' \
    'set --global fish_key_bindings fish_vi_key_bindings'
  run chezmoi_apply "$H" --no-tty
  [ "$status" -eq 0 ]
  grep -qx 'set --global fish_key_bindings fish_vi_key_bindings' "$H/.config/fish/conf.d/fish_frozen_key_bindings.fish"
}

@test "no retired target is still installed by the source" {
  run chezmoi_managed "$H"
  [ "$status" -eq 0 ]
  managed=$output
  retired=$(sed -n 's/^ *"\(\.[^"]*\)" ".*$/\1/p' "$REPO_ROOT/.chezmoiremove")
  [ -n "$retired" ]
  for t in $retired; do
    ! printf '%s\n' "$managed" | grep -qx "$t" || { echo "managed and retired: $t"; false; }
  done
}

# A failing .chezmoiremove template aborts the whole apply, so what it cannot
# read is skipped, never opened.
@test "a directory, an unreadable file or a symlink at a retired path is kept, and apply succeeds" {
  mkdir -p "$H/.config/fish/theme_preference" "$H/.config/direnv"
  put .config/fish/functions/__cached_init.fish 'function __cached_init'
  chmod 000 "$H/.config/fish/functions/__cached_init.fish"
  put real/direnvrc '# Support for uv (Python environment manager)'
  ln -s "$H/real/direnvrc" "$H/.config/direnv/direnvrc"
  run chezmoi_apply "$H" --no-tty
  chmod 644 "$H/.config/fish/functions/__cached_init.fish"
  [ "$status" -eq 0 ]
  [ -d "$H/.config/fish/theme_preference" ]
  [ -f "$H/.config/fish/functions/__cached_init.fish" ]
  [ -L "$H/.config/direnv/direnvrc" ]
}
