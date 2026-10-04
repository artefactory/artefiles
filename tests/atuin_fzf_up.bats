#!/usr/bin/env bats
# Up-arrow opens the atuin fzf picker (global history) wherever Ctrl+R does.

setup() {
  load 'helpers/setup'
  RENDERED="$BATS_TEST_TMPDIR/config.fish"
}

render_config() {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" "$1"
  chezmoi_render "$H" dot_config/fish/config.fish.tmpl > "$RENDERED"
}

@test "up-arrow is bound to the picker in default and insert mode with atuin" {
  render_config '{"modules":["atuin"]}'
  grep -qE "^    bind up '__atuin_fzf_up'" "$RENDERED"
  grep -qE "^        bind -M insert up '__atuin_fzf_up'" "$RENDERED"
}

@test "the up-arrow binding is absent without the atuin module" {
  render_config '{"modules":[]}'
  if grep -q '__atuin_fzf_up' "$RENDERED"; then return 1; fi
}

@test "the up-arrow opens the global picker and keeps native up in multi-line buffers" {
  f="$REPO_ROOT/dot_config/fish/functions/__atuin_fzf_up.fish"
  [ -f "$f" ]
  grep -q '__atuin_fzf_search global' "$f"
  grep -q 'up-or-search' "$f"
  grep -q 'commandline -L' "$f"
  grep -q 'commandline --search-mode; or commandline --paging-mode' "$f"
}

@test "the function parses" {
  command -v fish > /dev/null 2>&1 || skip "fish not available"
  fish -n "$REPO_ROOT/dot_config/fish/functions/__atuin_fzf_up.fish"
}

@test "the README lists the up-arrow among the picker's bindings" {
  grep -qE 'Ctrl\+R/Alt\+R/Alt\+F.*up-arrow|up-arrow.*Ctrl\+R' "$REPO_ROOT/README.md"
}
