#!/usr/bin/env bats
# Fish cannot run bash syntax, so the setup installs the bass plugin to replay
# a bash snippet's environment changes, and the README says what that covers.

setup() {
  load 'helpers/setup'
  README="$REPO_ROOT/README.md"
}

# section TITLE — the body of the "### TITLE" section, up to the next heading.
section() {
  awk -v t="### $1" '$0 == t {on=1; next} /^#{2,3} / {on=0} on' "$README"
}

@test "bass is listed in the fish plugins" {
  grep -qx 'edc/bass' "$REPO_ROOT/dot_config/fish/fish_plugins"
}

@test "the nvm integration only uses bass once the plugin is installed" {
  grep -qE 'functions -q bass' "$REPO_ROOT/dot_config/fish/config.fish.tmpl"
}

@test "the README documents running bash snippets from fish" {
  body=$(section "Running bash snippets in Fish")
  [ -n "$body" ]
  printf '%s\n' "$body" | grep -qF 'bass'
}

@test "the README says what works and what does not" {
  body=$(section "Running bash snippets in Fish")
  for word in 'bass source' 'bass export' 'bash script.sh' 'shebang' '[[ ]]' 'for x in' '$(...)'; do
    printf '%s\n' "$body" | grep -qF "$word" || { echo "missing: $word" >&2; return 1; }
  done
}
