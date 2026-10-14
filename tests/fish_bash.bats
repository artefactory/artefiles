#!/usr/bin/env bats
# Fish accepts only part of bash's syntax, so the setup installs the replay.fish
# plugin to replay a bash snippet's environment changes, and the README says what
# works natively and what needs it.

setup() {
  load 'helpers/setup'
  README="$REPO_ROOT/README.md"
}

# section TITLE — the body of the "### TITLE" section, up to the next heading.
section() {
  awk -v t="### $1" '$0 == t {on=1; next} /^#{2,3} / {on=0} on' "$README"
}

@test "replay.fish is listed in the fish plugins and bass is gone" {
  grep -qx 'jorgebucaran/replay.fish' "$REPO_ROOT/dot_config/fish/fish_plugins"
  if grep -rqi 'bass' "$REPO_ROOT/dot_config/fish/fish_plugins" "$REPO_ROOT/dot_config/fish/config.fish.tmpl" "$README"; then return 1; fi
}

@test "the README documents running bash snippets from fish" {
  body=$(section "Running bash snippets in Fish")
  [ -n "$body" ]
  printf '%s\n' "$body" | grep -qF 'replay.fish'
}

@test "the README says what works natively, what fails and what replay covers" {
  body=$(section "Running bash snippets in Fish")
  for word in 'fish 4.9.2' '$(...)' '&&' '{ a; b }' 'if ...; then' 'for x in' 'VAR=$(cmd)' "replay 'export PATH" "replay 'if [ -f" "replay 'VERSION=" "replay 'eval" 'bash script.sh' 'shebang' 'Bash functions are not copied'; do
    printf '%s\n' "$body" | grep -qF -- "$word" || { echo "missing: $word" >&2; return 1; }
  done
}

# Real runs of the README's replay examples, in a throwaway home with the plugin
# downloaded from GitHub; skipped when fish, git or GitHub are not reachable.
setup_replay_home() {
  command -v fish > /dev/null 2>&1 || skip "fish not available"
  command -v git > /dev/null 2>&1 || skip "git not available"
  RH="$BATS_TEST_TMPDIR/replay-home"
  mkdir -p "$RH/.config/fish/functions" "$RH/.local/bin" "$RH/bin"
  git clone -q --depth 1 https://github.com/jorgebucaran/replay.fish.git "$BATS_TEST_TMPDIR/replay.fish" 2> /dev/null \
    || skip "replay.fish cannot be downloaded"
  cp "$BATS_TEST_TMPDIR/replay.fish/functions/replay.fish" "$RH/.config/fish/functions/"
}

# in_fish SNIPPET — run SNIPPET in fish with only the plugin installed.
in_fish() {
  env -i HOME="$RH" PATH="/usr/bin:/bin:$(dirname "$(command -v fish)")" XDG_CONFIG_HOME="$RH/.config" \
    fish -c "$1" 2>&1 || return 1
}

@test "replay carries a PATH change into fish" {
  setup_replay_home
  run in_fish 'replay "export PATH=\"\$HOME/.local/bin:\$PATH\""; string match -q "*/.local/bin*" $PATH; and echo yes'
  [ "$output" = "yes" ]
}

@test "replay loads a .env file with if/then/fi syntax" {
  setup_replay_home
  printf 'API_KEY=abc123\nDEBUG=1\n' > "$RH/.env"
  run in_fish 'replay "if [ -f \"\$HOME/.env\" ]; then set -a; source \"\$HOME/.env\"; set +a; fi"; echo $API_KEY $DEBUG'
  [ "$output" = "abc123 1" ]
}

@test "replay accepts VAR=\$(cmd) and an eval of a tool's env output" {
  setup_replay_home
  run in_fish 'replay "VERSION=\$(echo 2026.10); export VERSION"; echo $VERSION'
  [ "$output" = "2026.10" ]
  run in_fish 'replay "eval \"\$(printf \"export HELLO=from-eval\")\""; echo $HELLO'
  [ "$output" = "from-eval" ]
}

@test "the same snippets fail in fish without replay, and replay does not copy bash functions" {
  setup_replay_home
  run in_fish 'VERSION=$(echo 2026.10)'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported use of '='"* ]]
  printf 'greet() { echo hi; }\nexport LOADED=yes\n' > "$RH/funcs.sh"
  run in_fish 'replay "source \"\$HOME/funcs.sh\""; echo $LOADED; functions -q greet; or echo no-function'
  [ "$output" = "$(printf 'yes\nno-function')" ]
}
