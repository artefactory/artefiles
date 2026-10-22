#!/usr/bin/env bats
# config.fish loads the direnv hook before the first prompt, so the first
# command of a new shell already runs with the .envrc environment.

setup() {
  load 'helpers/setup'
  command -v fish > /dev/null || skip "fish is not installed"
  command -v direnv > /dev/null || skip "direnv is not installed"
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  CONFIG="$BATS_TEST_TMPDIR/config.fish"
  chezmoi_render "$H" dot_config/fish/config.fish.tmpl > "$CONFIG"
  P="$BATS_TEST_TMPDIR/project"
  mkdir -p "$P"
  echo 'export KERAS_BACKEND=jax' > "$P/.envrc"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  ln -s "$(command -v direnv)" "$BIN/direnv"
  XDG_DATA_HOME="$H/.local/share" HOME="$H" direnv allow "$P"
}

# shell BEFORE AFTER — an interactive fish in the project that runs BEFORE,
# sources config.fish alone, then runs AFTER.
shell() {
  run env -i HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" \
    PATH="$BIN:/usr/bin:/bin" "$(command -v fish)" --no-config -i \
    -c "cd $P; $1; source $CONFIG; $2"
}

@test "the first prompt of a new shell exports the .envrc environment" {
  shell : 'emit fish_prompt; echo "first=[$KERAS_BACKEND]"'
  [[ "$output" == *"first=[jax]"* ]]
}

@test "a hook a vendor conf.d file already loaded is kept, not loaded again" {
  shell 'function __direnv_export_eval; echo vendor-hook; end' '__direnv_export_eval'
  [[ "$output" == *"vendor-hook"* ]]
}
