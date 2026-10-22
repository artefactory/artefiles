#!/usr/bin/env bats
# config.fish chooses fish's built-in Catppuccin Mocha in every interactive
# shell, whatever an older setup left behind; local.config.fish overrides it.

setup() {
  load 'helpers/setup'
  command -v fish > /dev/null || skip "fish is not installed"
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  CONFIG="$BATS_TEST_TMPDIR/config.fish"
  chezmoi_render "$H" dot_config/fish/config.fish.tmpl > "$CONFIG"
  mkdir -p "$H/.config/fish"
  # What fish 3 and the old detection block left: a universal colour and a
  # recorded theme name.
  printf '# This file contains fish universal variable definitions.\n# VERSION: 3.0\nSETUVAR fish_color_command:FF0000\n' \
    > "$H/.config/fish/fish_variables"
  echo 'Catppuccin Mocha' > "$H/.config/fish/theme_preference"
}

command_color() {
  run env -i HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="/usr/bin:/bin" \
    "$(command -v fish)" --no-config -i -c "source $CONFIG; echo \"color=\$fish_color_command\""
}

@test "an interactive shell gets Catppuccin Mocha despite an older theme setup" {
  command_color
  [[ "$output" == *"color="*"catppuccin-mocha"* ]]
}

@test "a theme chosen in local.config.fish wins" {
  echo 'fish_config theme choose nord' > "$H/.config/fish/local.config.fish"
  command_color
  [[ "$output" == *"color="*"nord"* ]]
}
