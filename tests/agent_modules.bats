#!/usr/bin/env bats
# The coding-agent modules: claude_code (Claude Code, from Anthropic's native
# installer, which updates itself), codex (OpenAI Codex CLI: Homebrew cask on
# macOS, GitHub release on Linux) and pi (pi coding agent, from its official
# installer with the Node that fnm installs). None is selected by default.

setup() {
  load 'helpers/setup'
}

PKG=.chezmoidata/packages.yaml
DARWIN_TMPL=.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl
DOCTOR=dot_config/fish/functions/dotfiles_doctor.fish.tmpl
CLAUDE_SCRIPT=.chezmoiscripts/run_install-claude-code.sh
PI_SCRIPT=.chezmoiscripts/run_after_install-pi.sh
AGENTS=(claude_code codex pi)

# render MODULES_JSON FILE — FILE rendered for a home with these modules.
render() {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  chezmoi_render "$H" "$2"
}

# defaults — the modules the template lists as preselected, one per line.
defaults() {
  # shellcheck disable=SC2016 # the pattern matches a literal `$defaults`
  sed -nE 's/^# \[\[ \$defaults := list (.*) \]\] #$/\1/p' "$REPO_ROOT/.chezmoi.toml.tmpl" | tr -d '"' | tr ' ' '\n'
}

@test "the init prompt offers claude_code, codex and pi right after antigravity, none checked by default" {
  [ "$(prompt_module_names | grep -A3 -x antigravity | tail -n +2 | tr '\n' ' ')" = "claude_code codex pi " ]
  for m in "${AGENTS[@]}"; do
    [ "$(defaults | grep -cx "$m")" -eq 0 ]
  done
  [[ "$(prompt_help claude_code)" == *"Claude Code"* ]]
  [[ "$(prompt_help codex)" == *"Codex"* ]]
  [[ "$(prompt_help pi)" == *"pi"* ]]
}

@test "codex installs the codex cask on macOS, only when selected" {
  [ "$(yq -o=json -I=0 '.packages.darwin.modules.codex.casks' "$REPO_ROOT/$PKG")" = '["codex"]' ]
  [ "$(yq -r '.packages.darwin.modules.codex.brews | length' "$REPO_ROOT/$PKG")" -eq 0 ]
  render '["codex"]' "$DARWIN_TMPL" | grep -qxF 'cask "codex"'
  [ "$(render '[]' "$DARWIN_TMPL" | grep -c '"codex"')" -eq 0 ]
}

@test "claude_code and pi install no Homebrew package: their own installers do" {
  for m in claude_code pi; do
    [ "$(yq -r ".packages.darwin.modules.$m | ((.brews // []) + (.casks // [])) | length" "$REPO_ROOT/$PKG")" -eq 0 ]
  done
  # One install path: the native installer, never the claude-code cask too.
  [ "$(grep -c 'claude-code' "$REPO_ROOT/$PKG")" -eq 0 ]
}

@test "the claude_code and pi install scripts are managed only with their module, on any OS" {
  for pair in "claude_code install-claude-code" "pi install-pi"; do
    set -- $pair
    render '[]' .chezmoiignore | grep -qxF ".chezmoiscripts/$2.sh"
    [ "$(render "[\"$1\"]" .chezmoiignore | grep -cxF ".chezmoiscripts/$2.sh")" -eq 0 ]
  done
}

# The scripts run with stubs only: no network, no real installer.
# agent_script SCRIPT [STUB...] — run SCRIPT with a PATH of stubs, each logging
# its calls to $CALLS. Knobs: CURL_FAIL=1 fails the download; NODE_FAIL=1
# makes the default Node too old (or absent); INSTALL_FAIL=1 fails the
# installer run through fnm. The curl stub writes a fake installer to its -o
# file. SCRIPT gets a stdin with a line of data, and the installer stubs (bash,
# and fnm when it runs bash) log "stdin:" and the line they read from theirs:
# empty when the script kept its stdin from the installer; fnm also logs the
# PATH it runs the installer with. `fnm exec --using=default node --version`
# prints v$NODE_VERSION (22.19.0 when unset). USER_PATH is appended to PATH.
agent_script() {
  local script="$1"
  shift
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  rm -rf "$BIN"
  mkdir -p "$BIN"
  : > "$CALLS"
  for real in mktemp rm cat head; do ln -sf "$(command -v "$real")" "$BIN/$real"; done
  for t in "$@"; do
    case "$t" in
    curl)
      cat > "$BIN/curl" <<STUB
#!/bin/sh
echo "curl \$*" >> "$CALLS"
[ -n "\$CURL_FAIL" ] && exit 22
out=
while [ \$# -gt 0 ]; do [ "\$1" = -o ] && out=\$2; shift; done
echo "echo installer" > "\$out"
STUB
      ;;
    bash)
      cat > "$BIN/bash" <<STUB
#!/bin/sh
echo "bash \$*" >> "$CALLS"
echo "stdin:\$(head -n 1)" >> "$CALLS"
[ -s "\$1" ]
STUB
      ;;
    fnm)
      cat > "$BIN/fnm" <<STUB
#!/bin/sh
echo "fnm \$*" >> "$CALLS"
case "\$*" in
*" node "*) [ -z "\$NODE_FAIL" ] && echo "v\${NODE_VERSION:-22.19.0}" ;;
*" bash "*)
  echo "stdin:\$(head -n 1)" >> "$CALLS"
  echo "PATH:\$PATH" >> "$CALLS"
  echo "pi installer output"
  [ -s "\$4" ] && [ -z "\$INSTALL_FAIL" ] ;;
esac
STUB
      ;;
    *) printf '#!/bin/sh\necho "%s $*" >> "%s"\n' "$t" "$CALLS" > "$BIN/$t" ;;
    esac
  done
  chmod +x "$BIN"/*
  # No terminal here: a stdin with data stands in for the apply's.
  echo "from the apply" > "$BATS_TEST_TMPDIR/stdin"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH="$BIN${USER_PATH:+:$USER_PATH}" CURL_FAIL="${CURL_FAIL:-}" \
    NODE_FAIL="${NODE_FAIL:-}" NODE_VERSION="${NODE_VERSION:-}" INSTALL_FAIL="${INSTALL_FAIL:-}" \
    /bin/sh "$REPO_ROOT/$script" < "$BATS_TEST_TMPDIR/stdin"
}

@test "claude_code: a claude already on PATH is kept and nothing is downloaded" {
  agent_script "$CLAUDE_SCRIPT" claude curl bash
  [ "$status" -eq 0 ]
  [ "$(grep -c -e '^curl' -e '^bash' "$CALLS")" -eq 0 ]
}

@test "claude_code: a claude in ~/.local/bin counts as installed, even off PATH" {
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/bin"
  printf '#!/bin/sh\n' > "$BATS_TEST_TMPDIR/home/.local/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/home/.local/bin/claude"
  agent_script "$CLAUDE_SCRIPT" curl bash
  [ "$status" -eq 0 ]
  [ "$(grep -c -e '^curl' -e '^bash' "$CALLS")" -eq 0 ]
}

@test "claude_code: the native installer is downloaded from claude.ai and run with bash on the stable channel" {
  agent_script "$CLAUDE_SCRIPT" curl bash
  [ "$status" -eq 0 ]
  grep -qE '^curl .*https://claude\.ai/install\.sh$' "$CALLS"
  # Downloaded to a file first, then run: sh has no pipefail, and a failed
  # download must not run a partial script.
  dl=$(grep -nE '^curl ' "$CALLS" | cut -d: -f1)
  run_at=$(grep -nE '^bash ' "$CALLS" | cut -d: -f1)
  [ -n "$run_at" ] && [ "$dl" -lt "$run_at" ]
  # The stable channel is the installer's only argument.
  [ "$(grep -cE '^bash ' "$CALLS")" -eq 1 ]
  grep -qE '^bash [^ ]+ stable$' "$CALLS"
  # The installer never reads the apply's stdin, as with the documented pipe.
  grep -qx 'stdin:' "$CALLS"
}

@test "claude_code: a failed download fails the apply and runs nothing" {
  CURL_FAIL=1 agent_script "$CLAUDE_SCRIPT" curl bash
  [ "$status" -ne 0 ]
  [[ "$output" == *"claude.ai/install.sh"* ]]
  [ "$(grep -c '^bash' "$CALLS")" -eq 0 ]
}

@test "claude_code: without bash or curl the script says what is missing and the apply goes on" {
  agent_script "$CLAUDE_SCRIPT" curl
  [ "$status" -eq 0 ]
  [[ "$output" == *"bash"* ]]
  agent_script "$CLAUDE_SCRIPT" bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"curl"* ]]
  [ "$(grep -c '^bash' "$CALLS")" -eq 0 ]
}

@test "pi: a pi already on PATH is kept and nothing is downloaded" {
  agent_script "$PI_SCRIPT" pi fnm curl bash
  [ "$status" -eq 0 ]
  [ "$(grep -c -e '^fnm' -e '^curl' -e '^bash' "$CALLS")" -eq 0 ]
}

@test "pi: a pi in ~/.local/bin counts as installed, even off PATH" {
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/bin"
  printf '#!/bin/sh\n' > "$BATS_TEST_TMPDIR/home/.local/bin/pi"
  chmod +x "$BATS_TEST_TMPDIR/home/.local/bin/pi"
  agent_script "$PI_SCRIPT" fnm curl bash
  [ "$status" -eq 0 ]
  [ "$(grep -c -e '^fnm' -e '^curl' -e '^bash' "$CALLS")" -eq 0 ]
}

@test "pi: without fnm, bash or curl the script says what is missing and the apply goes on" {
  agent_script "$PI_SCRIPT" curl bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"fnm"* ]]
  [ "$(grep -c '^curl' "$CALLS")" -eq 0 ]
  agent_script "$PI_SCRIPT" fnm curl
  [ "$status" -eq 0 ]
  [[ "$output" == *"bash"* ]]
  [ "$(grep -c -e '^fnm' -e '^curl' "$CALLS")" -eq 0 ]
  agent_script "$PI_SCRIPT" fnm bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"curl"* ]]
  [ "$(grep -c '^fnm' "$CALLS")" -eq 0 ]
}

@test "pi: without a default Node 22.19 or newer the install is skipped with a message" {
  NODE_FAIL=1 agent_script "$PI_SCRIPT" fnm curl bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"22.19"* ]]
  [ "$(grep -c -e '^curl' -e ' bash ' "$CALLS")" -eq 0 ]
}

@test "pi: Node 22.18, 22.9 and 21.99 are too old; 22.19, 22.20 and 23.0 install" {
  for v in 22.18.0 22.9.0 21.99.0; do
    NODE_VERSION=$v agent_script "$PI_SCRIPT" fnm curl bash
    [ "$status" -eq 0 ]
    [[ "$output" == *"22.19"* ]] || { echo "$v: no message" >&2; return 1; }
    [ "$(grep -c ' bash ' "$CALLS")" -eq 0 ] || { echo "$v: installer ran" >&2; return 1; }
  done
  for v in 22.19.0 22.20.1 23.0.0; do
    NODE_VERSION=$v agent_script "$PI_SCRIPT" fnm curl bash
    [ "$status" -eq 0 ]
    [ "$(grep -c '^fnm exec --using=default bash ' "$CALLS")" -eq 1 ] || { echo "$v: installer not run" >&2; return 1; }
  done
}

@test "pi: the installer sees ~/.local/bin first, so it links its launcher there" {
  # The installer takes the first of ~/.local/bin, ~/bin, ~/.bin, ~/local/bin
  # and ~/.pi/agent/bin in PATH order; fnm exec only prepends its Node bin
  # dir, which is none of them.
  home="$BATS_TEST_TMPDIR/home"
  USER_PATH="$home/bin:$home/.bin" agent_script "$PI_SCRIPT" fnm curl bash
  [ "$status" -eq 0 ]
  [[ "$(grep '^PATH:' "$CALLS")" == "PATH:$home/.local/bin:"* ]]
}

@test "pi: before the installer runs, the apply says it may wait for Enter at a terminal" {
  agent_script "$PI_SCRIPT" fnm curl bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"Enter"*"pi installer output"* ]]
}

@test "pi: the official installer is downloaded from pi.dev and run with fnm's default Node, off the apply's stdin" {
  agent_script "$PI_SCRIPT" fnm curl bash
  [ "$status" -eq 0 ]
  grep -qE '^curl .*https://pi\.dev/install\.sh$' "$CALLS"
  # fnm puts its default Node and npm on PATH for the installer's checks.
  [ "$(grep -cE '^fnm exec --using=default bash [^ ]+$' "$CALLS")" -eq 1 ]
  [ "$(grep -c '^bash ' "$CALLS")" -eq 0 ]
  # The Node version is checked, then the installer downloaded, then run.
  node_at=$(grep -nE '^fnm exec --using=default node ' "$CALLS" | cut -d: -f1)
  dl=$(grep -nE '^curl ' "$CALLS" | cut -d: -f1)
  run_at=$(grep -nE '^fnm exec --using=default bash ' "$CALLS" | cut -d: -f1)
  [ -n "$node_at" ] && [ "$node_at" -lt "$dl" ] && [ "$dl" -lt "$run_at" ]
  grep -qx 'stdin:' "$CALLS"
  # Its output still reaches the apply.
  [[ "$output" == *"pi installer output"* ]]
}

@test "pi: a failed download fails the apply and runs nothing" {
  CURL_FAIL=1 agent_script "$PI_SCRIPT" fnm curl bash
  [ "$status" -ne 0 ]
  [[ "$output" == *"pi.dev/install.sh"* ]]
  [ "$(grep -c ' bash ' "$CALLS")" -eq 0 ]
}

@test "pi: a failed installer run fails the apply, its output shown" {
  INSTALL_FAIL=1 agent_script "$PI_SCRIPT" fnm curl bash
  [ "$status" -ne 0 ]
  [[ "$output" == *"pi installer output"* ]]
}

@test "the doctor checks claude, codex and pi, each with its module" {
  render '[]' "$DOCTOR" | { ! grep -qE '__check_tool_with_configs (claude|codex|pi) '; }
  [ "$(render '[]' "$DOCTOR" | grep -c '## Coding agents')" -eq 0 ]
  for pair in "claude_code claude" "codex codex" "pi pi"; do
    set -- $pair
    out=$(render "[\"$1\"]" "$DOCTOR")
    grep -qxF "    __check_tool_with_configs $2 \"\" \$managed_files" <<< "$out"
    [ "$(grep -c '## Coding agents' <<< "$out")" -eq 1 ]
    [ "$(grep -cE '__check_tool_with_configs (claude|codex|pi) ' <<< "$out")" -eq 1 ]
  done
  [ "$(render '["claude_code","codex","pi"]' "$DOCTOR" | grep -c '## Coding agents')" -eq 1 ]
}

@test "the three modules have their README and cheatsheet rows and a reference" {
  for m in "${AGENTS[@]}"; do
    grep -qF "| \`$m\` | $(prompt_help "$m") | — |" "$REPO_ROOT/README.md"
    grep -qF "| \`$m\` | $(prompt_help "$m") | [$m](.claude/skills/artefiles/references/$m.md) |" "$REPO_ROOT/CHEATSHEET.md"
    [ -f "$REPO_ROOT/.claude/skills/artefiles/references/$m.md" ]
  done
  # The README rows follow antigravity in the same order as the prompt.
  [ "$(grep -A3 -F '| `antigravity` |' "$REPO_ROOT/README.md" | tail -n +2 | cut -d'`' -f2 | tr '\n' ' ')" = "claude_code codex pi " ]
  [ "$(grep -A3 -F '| `antigravity` |' "$REPO_ROOT/CHEATSHEET.md" | tail -n +2 | cut -d'`' -f2 | tr '\n' ' ')" = "claude_code codex pi " ]
}
