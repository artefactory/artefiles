#!/usr/bin/env bats
# config.fish sources each tool's generated init on every start, so a change
# of the tool's output (new flags, new environment) applies to the next shell,
# even when the tool's binary itself did not change.

setup() {
  load 'helpers/setup'
  command -v fish > /dev/null || skip "fish is not installed"
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["atuin"]}'
  CONFIG="$BATS_TEST_TMPDIR/config.fish"
  chezmoi_render "$H" dot_config/fish/config.fish.tmpl > "$CONFIG"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
}

# tools VERSION — fzf and atuin stubs whose init code sets VERSION. The stubs
# keep an old mtime, like a binary nobody upgraded.
tools() {
  printf '#!/bin/sh\necho "set -g FZF_INIT %s"\n' "$1" > "$BIN/fzf"
  cat > "$BIN/atuin" << EOF
#!/bin/sh
case "\$1" in
  init) echo "set -g ATUIN_INIT $1" ;;
  gen-completions) echo "set -g ATUIN_COMPLETIONS $1" ;;
esac
EOF
  chmod +x "$BIN/fzf" "$BIN/atuin"
  touch -t 200001010000 "$BIN/fzf" "$BIN/atuin"
}

# shell — a new interactive shell with config.fish alone; it reports which
# version each init set.
shell() {
  run env -i HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_CACHE_HOME="$H/.cache" PATH="$BIN:/usr/bin:/bin" \
    "$(command -v fish)" --no-config -i -c "
      set fish_function_path $REPO_ROOT/dot_config/fish/functions \$fish_function_path
      source $CONFIG
      echo \"fzf=\$FZF_INIT atuin=\$ATUIN_INIT completions=\$ATUIN_COMPLETIONS\""
}

@test "each new shell runs the tools' current init, never an earlier one" {
  tools v1
  shell
  [[ "$output" == *"fzf=v1 atuin=v1 completions=v1"* ]]
  tools v2
  shell
  [[ "$output" == *"fzf=v2 atuin=v2 completions=v2"* ]]
}
