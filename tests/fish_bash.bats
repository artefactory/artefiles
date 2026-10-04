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

@test "the nvm integration only uses replay once the plugin is installed" {
  grep -qE 'functions -q replay' "$REPO_ROOT/dot_config/fish/config.fish.tmpl"
}

@test "the README documents running bash snippets from fish" {
  body=$(section "Running bash snippets in Fish")
  [ -n "$body" ]
  printf '%s\n' "$body" | grep -qF 'replay.fish'
}

@test "the README says what works natively, what fails and what replay covers" {
  body=$(section "Running bash snippets in Fish")
  for word in 'fish 4.9.2' '$(...)' '&&' '{ a; b }' 'if ...; then' 'for x in' 'VAR=$(cmd)' "replay 'source" "replay 'export" 'bash script.sh' 'shebang'; do
    printf '%s\n' "$body" | grep -qF -- "$word" || { echo "missing: $word" >&2; return 1; }
  done
}
