#!/usr/bin/env bats
# The vscode module installs the VS Code desktop app (Homebrew cask on macOS,
# Microsoft's apt repository on Linux); the code_cli module installs the
# standalone VS Code CLI on Linux as code-cli, so it never shadows the app's
# `code`. Both are selected by default.

setup() {
  load 'helpers/setup'
}

PKG=.chezmoidata/packages.yaml
DARWIN_TMPL=.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl
DOCTOR=dot_config/fish/functions/dotfiles_doctor.fish.tmpl
VSCODE_SCRIPT=.chezmoiscripts/linux/run_install-vscode.sh

# render MODULES_JSON FILE — FILE rendered for a home with these modules.
render() {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  chezmoi_render "$H" "$2"
}

# linux_render MODULES_JSON FILE [ARCH] — FILE rendered as on Linux, on ARCH
# (the host's when omitted).
linux_render() {
  local arch_sed='s/^//'
  [ -n "${3:-}" ] && arch_sed="s/\\.chezmoi\\.arch/\"$3\"/g"
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < <(sed -e 's/eq \.chezmoi\.os "linux"/true/' -e "$arch_sed" "$REPO_ROOT/$2")
}

# defaults — the modules the template lists as preselected, one per line.
defaults() {
  # shellcheck disable=SC2016 # the pattern matches a literal `$defaults`
  sed -nE 's/^# \[\[ \$defaults := list (.*) \]\] #$/\1/p' "$REPO_ROOT/.chezmoi.toml.tmpl" | tr -d '"' | tr ' ' '\n'
}

# code_cli_block MODULES_JSON [ARCH] — the code-cli entry of the Linux externals.
code_cli_block() {
  linux_render "$1" .chezmoiexternal.toml.tmpl "${2:-}" | awk '
    /^\[/ { on = ($0 == "[\".local/bin/code-cli\"]") }
    on'
}

@test "the init prompt offers vscode and code_cli, both checked by default" {
  for m in vscode code_cli; do
    prompt_module_names | grep -qx "$m"
    defaults | grep -qx "$m"
  done
  [[ "$(prompt_help vscode)" == *"VS Code"* ]]
  [[ "$(prompt_help code_cli)" == *"code-cli"* ]]
}

@test "vscode installs the visual-studio-code cask on macOS, only when selected" {
  [ "$(yq -r '.packages.darwin.modules.vscode.casks[0]' "$REPO_ROOT/$PKG")" = visual-studio-code ]
  render '["vscode"]' "$DARWIN_TMPL" | grep -qxF 'cask "visual-studio-code"'
  [ "$(render '[]' "$DARWIN_TMPL" | grep -c 'visual-studio-code')" -eq 0 ]
  [ "$(render '["code_cli"]' "$DARWIN_TMPL" | grep -c 'visual-studio-code')" -eq 0 ]
}

@test "code_cli installs nothing on macOS" {
  [ "$(yq -r '.packages.darwin.modules.code_cli | ((.brews // []) + (.casks // [])) | length' "$REPO_ROOT/$PKG")" -eq 0 ]
}

@test "on Linux, code_cli downloads the standalone CLI for the host arch as code-cli" {
  [ -n "$(code_cli_block '["code_cli"]' amd64)" ]
  code_cli_block '["code_cli"]' amd64 \
    | grep -qxF '  url = "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64"'
  code_cli_block '["code_cli"]' arm64 \
    | grep -qxF '  url = "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-arm64"'
  block=$(code_cli_block '["code_cli"]' amd64)
  # The URL names no file, so the archive format must be stated; a fixed URL is
  # downloaded again only once refreshPeriod has passed.
  grep -qxF '  type = "archive-file"' <<< "$block"
  grep -qxF '  format = "tar.gz"' <<< "$block"
  grep -qxF '  path = "code"' <<< "$block"
  grep -qxF '  executable = true' <<< "$block"
  grep -qE '^  refreshPeriod = "[0-9]+h"$' <<< "$block"
}

@test "on 32-bit ARM Linux, code_cli downloads the armhf CLI; other arches get none" {
  code_cli_block '["code_cli"]' arm \
    | grep -qxF '  url = "https://code.visualstudio.com/sha/download?build=stable&os=cli-linux-armhf"'
  [ -z "$(code_cli_block '["code_cli"]' 386)" ]
  [ -z "$(code_cli_block '["code_cli"]' riscv64)" ]
}

@test "the doctor checks code-cli only on an arch that gets it" {
  linux_render '["code_cli"]' "$DOCTOR" arm | grep -qE '__check_tool_with_configs code-cli ""'
  [ "$(linux_render '["code_cli"]' "$DOCTOR" 386 | grep -cE 'code-cli')" -eq 0 ]
}

@test "the code_cli help and docs say it is Linux only, and name code tunnel for macOS" {
  [[ "$(prompt_help code_cli)" == *"Linux only"* ]]
  [[ "$(prompt_help code_cli)" == *"code tunnel"* ]]
  grep -qF 'Linux only' "$REPO_ROOT/.claude/skills/artefiles/references/code_cli.md"
}

@test "on Linux, code-cli is not installed without code_cli" {
  [ -z "$(code_cli_block '[]')" ]
  [ -z "$(code_cli_block '["vscode"]')" ]
}

@test "with both modules nothing but the desktop app installs a code command" {
  externals=$(linux_render '["vscode","code_cli"]' .chezmoiexternal.toml.tmpl)
  [ "$(grep -cxF '[".local/bin/code"]' <<< "$externals")" -eq 0 ]
  grep -qxF '[".local/bin/code-cli"]' <<< "$externals"
  [ "$(yq -r '.packages.darwin.modules.code_cli.casks // [] | .[]' "$REPO_ROOT/$PKG" | grep -c .)" -eq 0 ]
}

@test "on Linux, the vscode install script is managed only with vscode" {
  [ -f "$REPO_ROOT/$VSCODE_SCRIPT" ]
  linux_render '[]' .chezmoiignore | grep -qxF '.chezmoiscripts/linux/install-vscode.sh'
  [ "$(linux_render '["vscode"]' .chezmoiignore | grep -cxF '.chezmoiscripts/linux/install-vscode.sh')" -eq 0 ]
}

# The Linux script runs with stubs only: no real sudo, apt-get or network.
# vscode_script [STUB...] — run it with a PATH of stubs; sudo, curl, gpg, tee
# and apt-get log their calls to $CALLS, and the sudo stub runs its command.
# Knobs: SUDO_DENY=1 makes `sudo -n` fail; CURL_FAIL=1 fails the download;
# APT_FAIL=update|install fails that apt-get subcommand. The session has
# DISPLAY=$T_DISPLAY (":0" when unset, none when empty), and
# WAYLAND_DISPLAY / CODESPACES when T_WAYLAND / T_CODESPACES are set.
vscode_script() {
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BIN"
  : > "$CALLS"
  for real in env mktemp rm cat; do ln -sf "$(command -v "$real")" "$BIN/$real"; done
  for t in "$@"; do
    case "$t" in
    sudo)
      printf '#!/bin/sh\necho "sudo $*" >> "%s"\nif [ "$1" = -n ]; then [ -n "$SUDO_DENY" ] && exit 1; exit 0; fi\nexec "$@"\n' \
        "$CALLS" > "$BIN/sudo" ;;
    tee) printf '#!/bin/sh\necho "tee $*" >> "%s"\n/bin/cat >> "%s"\n' "$CALLS" "$CALLS" > "$BIN/tee" ;;
    curl)
      printf '#!/bin/sh\necho "curl $*" >> "%s"\n[ -n "$CURL_FAIL" ] && exit 22\nout=\nwhile [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done\nif [ -n "$out" ]; then echo KEY > "$out"; else echo KEY; fi\n' \
        "$CALLS" > "$BIN/curl" ;;
    gpg) printf '#!/bin/sh\necho "gpg $*" >> "%s"\n/bin/cat\n' "$CALLS" > "$BIN/gpg" ;;
    apt-get)
      printf '#!/bin/sh\necho "apt-get $*" >> "%s"\n[ -n "$APT_FAIL" ] && [ "$1" = "$APT_FAIL" ] && exit 100\nexit 0\n' \
        "$CALLS" > "$BIN/apt-get" ;;
    root) printf '#!/bin/sh\necho 0\n' > "$BIN/id" ;;
    user) printf '#!/bin/sh\necho 1000\n' > "$BIN/id" ;;
    *) printf '#!/bin/sh\necho "%s $*" >> "%s"\n' "$t" "$CALLS" > "$BIN/$t" ;;
    esac
  done
  chmod +x "$BIN"/*
  local vars=(HOME="$BATS_TEST_TMPDIR" PATH="$BIN" SUDO_DENY="${SUDO_DENY:-}"
    CURL_FAIL="${CURL_FAIL:-}" APT_FAIL="${APT_FAIL:-}")
  local display="${T_DISPLAY-:0}"
  [ -n "$display" ] && vars+=(DISPLAY="$display")
  [ -n "${T_WAYLAND:-}" ] && vars+=(WAYLAND_DISPLAY="$T_WAYLAND")
  [ -n "${T_CODESPACES:-}" ] && vars+=(CODESPACES="$T_CODESPACES")
  run env -i "${vars[@]}" /bin/sh "$REPO_ROOT/$VSCODE_SCRIPT" < /dev/null
}

# The stubs for a full install as a user with sudo.
INSTALL=(user sudo tee apt-get curl gpg)

@test "on Linux, a code already on PATH is kept and nothing is installed" {
  vscode_script code "${INSTALL[@]}"
  [ "$status" -eq 0 ]
  [ "$(grep -c -e '^sudo' -e '^apt-get' -e '^curl' "$CALLS")" -eq 0 ]
}

@test "on Linux, without a display the desktop app is skipped and code_cli is named" {
  T_DISPLAY= vscode_script "${INSTALL[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"code_cli"* ]]
  [ "$(grep -c -e '^apt-get' -e '^sudo' -e '^curl' "$CALLS")" -eq 0 ]
}

@test "on Linux, a Wayland session counts as a display" {
  T_DISPLAY= T_WAYLAND=wayland-0 vscode_script "${INSTALL[@]}"
  [ "$status" -eq 0 ]
  grep -qE '^apt-get install -y code$' "$CALLS"
}

@test "in a Codespace the desktop app is skipped, even with a display" {
  T_CODESPACES=true vscode_script "${INSTALL[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"code_cli"* ]]
  [ "$(grep -c -e '^apt-get' -e '^sudo' -e '^curl' "$CALLS")" -eq 0 ]
}

@test "on Linux, without apt-get the script says where to get VS Code and succeeds" {
  vscode_script user sudo tee curl gpg
  [ "$status" -eq 0 ]
  [[ "$output" == *"code.visualstudio.com/docs/setup/linux"* ]]
  [ "$(grep -c '^sudo' "$CALLS")" -eq 0 ]
}

@test "on Linux, without sudo rights or a terminal nothing is installed and apply goes on" {
  SUDO_DENY=1 vscode_script "${INSTALL[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"administrator"* ]]
  [ "$(grep -c 'install -y code' "$CALLS")" -eq 0 ]
}

@test "on Linux, with a display and sudo the code package comes from Microsoft's apt repository" {
  vscode_script "${INSTALL[@]}"
  [ "$status" -eq 0 ]
  grep -qE '^curl .*https://packages\.microsoft\.com/keys/microsoft\.asc$' "$CALLS"
  grep -qxF 'sudo tee /usr/share/keyrings/microsoft.gpg' "$CALLS"
  grep -qxF 'sudo tee /etc/apt/sources.list.d/vscode.sources' "$CALLS"
  grep -qxF 'URIs: https://packages.microsoft.com/repos/code' "$CALLS"
  grep -qxF 'Signed-By: /usr/share/keyrings/microsoft.gpg' "$CALLS"
  # The repository is declared before the package is installed from it.
  repo=$(grep -nxF 'sudo tee /etc/apt/sources.list.d/vscode.sources' "$CALLS" | cut -d: -f1)
  pkg=$(grep -nE '^sudo .*apt-get install -y code$' "$CALLS" | cut -d: -f1)
  [ -n "$pkg" ] && [ "$repo" -lt "$pkg" ]
}

@test "on Linux, as root the script installs without sudo" {
  vscode_script root sudo tee apt-get curl gpg
  [ "$status" -eq 0 ]
  [ "$(grep -c '^sudo' "$CALLS")" -eq 0 ]
  grep -qE '^apt-get install -y code$' "$CALLS"
}

@test "on Linux, a failed key download stops the install before any key is written" {
  CURL_FAIL=1 vscode_script "${INSTALL[@]}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"packages.microsoft.com/keys/microsoft.asc"* ]]
  [ "$(grep -c 'tee /usr/share/keyrings/microsoft.gpg' "$CALLS")" -eq 0 ]
  [ "$(grep -c 'install -y code' "$CALLS")" -eq 0 ]
}

@test "on Linux, a failed apt-get update warns and lets the apply go on" {
  APT_FAIL=update vscode_script "${INSTALL[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get update"* ]]
  [ "$(grep -c 'install -y code' "$CALLS")" -eq 0 ]
}

@test "on Linux, a failed install of the code package fails the apply" {
  APT_FAIL=install vscode_script "${INSTALL[@]}"
  [ "$status" -ne 0 ]
}

# linux_doctor MODULES_JSON [VAR=VALUE...] — run the doctor rendered as on
# Linux, with stubs for the core tools and chezmoi, in a session with only
# these variables, so no DISPLAY unless one is given.
linux_doctor() {
  command -v fish > /dev/null || skip "fish is not installed"
  local bin="$BATS_TEST_TMPDIR/dbin" src="$BATS_TEST_TMPDIR/dsrc"
  mkdir -p "$bin" "$src"
  if [ ! -d "$src/.git" ]; then
    git -C "$src" init -q -b main
    git -C "$src" -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.email=t@e -c user.name=t commit -q --allow-empty -m init
  fi
  # The real git reads the source repository; every other tool is a stub.
  # Written fresh each call: rm first, so a write never follows a symlink.
  rm -f "$bin"/*
  for t in fish starship gh fnm mergiraf uv hostname; do
    printf '#!/bin/sh\necho "%s 1.0"\n' "$t" > "$bin/$t"
  done
  printf '#!/bin/sh\ncase "$1" in source-path) echo "%s" ;; doctor) echo "ok version v2" ;; esac\n' "$src" > "$bin/chezmoi"
  chmod +x "$bin"/*
  ln -s "$(command -v git)" "$bin/git"
  linux_render "$1" "$DOCTOR" > "$BATS_TEST_TMPDIR/dd.fish" || return 1
  [ -s "$BATS_TEST_TMPDIR/dd.fish" ]
  run env -i HOME="$BATS_TEST_TMPDIR" PATH="$bin:/usr/bin:/bin" "${@:2}" "$(command -v fish)" --no-config \
    -c "source $BATS_TEST_TMPDIR/dd.fish; dotfiles_doctor"
}

@test "on a Linux server or in a Codespace a missing code is a warning, as the install skips it there" {
  linux_doctor '["vscode"]'
  [ "$status" -eq 0 ]
  [[ "$output" == *"! code: not installed"*"code_cli"* ]]
  linux_doctor '["vscode"]' DISPLAY=:0 CODESPACES=true
  [ "$status" -eq 0 ]
  [[ "$output" == *"! code: not installed"* ]]
}

@test "on a Linux desktop a missing code is a problem" {
  linux_doctor '["vscode"]' DISPLAY=:0
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ code: not installed"* ]]
  linux_doctor '["vscode"]' WAYLAND_DISPLAY=wayland-0
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ code: not installed"* ]]
}

@test "the doctor checks code with vscode and code-cli with code_cli on Linux" {
  render '["vscode"]' "$DOCTOR" | grep -qE '__check_tool_with_configs code ""'
  linux_render '["vscode"]' "$DOCTOR" | grep -qE '__check_tool_with_configs code ""'
  [ "$(render '[]' "$DOCTOR" | grep -cE '__check_tool_with_configs code(-cli)? ')" -eq 0 ]
  linux_render '["code_cli"]' "$DOCTOR" | grep -qE '__check_tool_with_configs code-cli ""'
  [ "$(render '["code_cli"]' "$DOCTOR" | grep -cE '__check_tool_with_configs code-cli ')" -eq "$([ "$(uname -s)" = Linux ] && echo 1 || echo 0)" ]
}

@test "README and CHEATSHEET list both modules, and the README names every default" {
  for m in vscode code_cli; do
    grep -qF "| \`$m\` | $(prompt_help "$m") | — |" "$REPO_ROOT/README.md"
    grep -qF "| \`$m\` | $(prompt_help "$m") | [$m](.claude/skills/artefiles/references/$m.md) |" "$REPO_ROOT/CHEATSHEET.md"
    [ -f "$REPO_ROOT/.claude/skills/artefiles/references/$m.md" ]
  done
  listed=$(sed -nE 's/^Selected by default: (.*)\.$/\1/p' "$REPO_ROOT/README.md" | tr -d '`' | sed 's/, /,/g' | tr ',' '\n')
  [ "$listed" = "$(defaults)" ]
}

@test "python_dev keeps working with any code on PATH, from vscode or not" {
  grep -qF 'command -v code' "$REPO_ROOT/.chezmoiscripts/run_after_install-vscode-extensions.sh.tmpl"
  grep -qF 'vscode' "$REPO_ROOT/.claude/skills/artefiles/references/python_dev.md"
}
