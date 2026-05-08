#!/usr/bin/env bats
# Regression guard against stale references that #66 cleaned up.
#
# wezterm and glab are no longer shipped or referenced; this test fails
# fast if either reappears in fish config or function source.

setup() {
  load 'helpers/setup'
}

@test "no wezterm references in dot_config/" {
  if grep -RIni 'wezterm' "$REPO_ROOT/dot_config/" 2>/dev/null; then
    echo "wezterm references found in dot_config/ (forbidden — see #66)" >&2
    return 1
  fi
}

@test "no glab references in dotfiles_doctor.fish" {
  if grep -ni 'glab' "$REPO_ROOT/dot_config/fish/functions/dotfiles_doctor.fish" 2>/dev/null; then
    echo "glab references found in dotfiles_doctor.fish (forbidden — see #66)" >&2
    return 1
  fi
}

@test ".chezmoiignore does not list previously-removed dead refs" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(SSH_CLIENT="dummy 1 2" chezmoi_render "$H" .chezmoiignore)

  # Files that were referenced but never existed in the repo — see #66.
  for dead in TODO.md TEST.md test-dotfiles.sh test-dotfiles.fish \
              .install-1password-cli.sh scripts/install-wezterm-remote.sh; do
    if printf '%s\n' "$rendered" | grep -qF "$dead"; then
      echo ".chezmoiignore still references removed-as-dead path: $dead" >&2
      return 1
    fi
  done
}
