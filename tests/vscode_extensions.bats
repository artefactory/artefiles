#!/usr/bin/env bats
# Verify that VSCode extensions are driven by packages.yaml rather than
# hardcoded in the shell script.

setup() {
  load 'helpers/setup'
}

EXT=.chezmoiscripts/run_after_install-vscode-extensions.sh.tmpl

# ext_script MODULES_JSON [INSTALLED...] — run the extension script rendered for
# these modules, with a `code` stub whose --list-extensions prints INSTALLED.
# Every call to the stub is logged to $CALLS. NO_CODE=1 leaves `code` off PATH.
ext_script() {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  chezmoi_render "$H" "$EXT" > "$BATS_TEST_TMPDIR/ext.sh" || return 1
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BIN"
  : > "$CALLS"
  printf '%s\n' "${@:2}" > "$BATS_TEST_TMPDIR/installed"
  rm -f "$BIN/code"
  if [ -z "${NO_CODE:-}" ]; then
    printf '#!/bin/sh\necho "code $*" >> "%s"\n[ "$1" = --list-extensions ] && cat "%s"\nexit 0\n' \
      "$CALLS" "$BATS_TEST_TMPDIR/installed" > "$BIN/code"
    chmod +x "$BIN/code"
  fi
  run env -i PATH="$BIN:/usr/bin:/bin" /bin/sh "$BATS_TEST_TMPDIR/ext.sh"
}

core_extensions() { yq -r '.vscode.extensions[]' "$REPO_ROOT/.chezmoidata/packages.yaml"; }

@test "the extension script runs on every apply, so VS Code installed on a later apply gets its extensions" {
  # A run_onchange_ script that found no `code` would be recorded as done and
  # never run again once VS Code arrives.
  [ -f "$REPO_ROOT/$EXT" ]
  [ ! -e "$REPO_ROOT/.chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl" ]
}

@test "with every extension installed, code is asked once and nothing is installed" {
  # shellcheck disable=SC2046 # IDs hold no spaces
  ext_script '[]' $(core_extensions)
  [ "$status" -eq 0 ]
  [ "$(grep -c '^code --list-extensions' "$CALLS")" -eq 1 ]
  [ "$(grep -c '^code --install-extension' "$CALLS")" -eq 0 ]
}

@test "only the missing extensions are installed; IDs match whole and ignore case" {
  # Lowercased, as IDs are case-insensitive; the icons are no proof that the
  # theme of the same prefix is installed.
  ext_script '[]' catppuccin.catppuccin-vsc-icons mkhl.direnv
  [ "$status" -eq 0 ]
  [ "$(grep -c '^code --list-extensions' "$CALLS")" -eq 1 ]
  [ "$(grep -c '^code --install-extension' "$CALLS")" -eq 1 ]
  grep -qxF 'code --install-extension Catppuccin.catppuccin-vsc' "$CALLS"
}

@test "without code the extension script does nothing and succeeds" {
  NO_CODE=1 ext_script '["python_dev"]'
  [ "$status" -eq 0 ]
  [ ! -s "$CALLS" ]
}

@test "all core yaml extensions appear in rendered install script" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" "$EXT")
  while IFS= read -r ext; do
    if ! echo "$rendered" | grep -qxF "install_extension \"$ext\""; then
      echo "Extension '$ext' not found in rendered script" >&2
      return 1
    fi
  done < <(yq -r '.vscode.extensions[]' "$REPO_ROOT/.chezmoidata/packages.yaml")
}

@test "defaults are the theme, icons and direnv; the Python extensions belong to python_dev" {
  defaults=$(yq -r '.vscode.extensions[]' "$REPO_ROOT/.chezmoidata/packages.yaml")
  python_dev=$(yq -r '.vscode.modules.python_dev.extensions[]' "$REPO_ROOT/.chezmoidata/packages.yaml")
  for ext in "Catppuccin.catppuccin-vsc" "Catppuccin.catppuccin-vsc-icons" "mkhl.direnv"; do
    echo "$defaults" | grep -qxF "$ext"
  done
  for ext in "ms-python.python" "ms-python.vscode-pylance" "charliermarsh.ruff"; do
    if echo "$defaults" | grep -qxF "$ext"; then return 1; fi
    echo "$python_dev" | grep -qxF "$ext"
  done
}

@test "python_dev installs the Python extensions; without it they are absent" {
  H_on=$(mk_fake_home "$BATS_TEST_TMPDIR/on")
  seed_chezmoi_config "$H_on" '{"modules":["python_dev"]}'
  on=$(chezmoi_render "$H_on" "$EXT")
  H_off=$(mk_fake_home "$BATS_TEST_TMPDIR/off")
  seed_chezmoi_config "$H_off" '{"modules":[]}'
  off=$(chezmoi_render "$H_off" "$EXT")
  for ext in "ms-python.python" "ms-python.vscode-pylance" "charliermarsh.ruff"; do
    echo "$on" | grep -qxF "install_extension \"$ext\""
    if echo "$off" | grep -qxF "install_extension \"$ext\""; then return 1; fi
  done
}

@test "the VS Code app is installed by the vscode module only, and is a default" {
  [ "$(yq -r '.packages.darwin.core.casks[]' "$REPO_ROOT/.chezmoidata/packages.yaml" | grep -c visual-studio-code)" -eq 0 ]
  yq -r '.packages.darwin.modules.vscode.casks[]' "$REPO_ROOT/.chezmoidata/packages.yaml" | grep -qxF visual-studio-code
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  ! echo "$rendered" | grep -q 'visual-studio-code'
  # shellcheck disable=SC2016 # the pattern matches a literal `$defaults`
  grep -E '^# \[\[ \$defaults := ' "$REPO_ROOT/.chezmoi.toml.tmpl" | grep -qF '"vscode"'
}

@test "docs present VS Code as a module, not as part of every install" {
  if grep -nE '^Every install gives you.*VS Code' "$REPO_ROOT/README.md"; then return 1; fi
  grep -qF '| `vscode` |' "$REPO_ROOT/README.md"
  grep -qF '| `vscode` |' "$REPO_ROOT/CHEATSHEET.md"
}

@test "per-module extensions absent when module not selected" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" "$EXT")
  core=$(yq -r '.vscode.extensions // [] | .[]' "$REPO_ROOT/.chezmoidata/packages.yaml")
  while IFS= read -r ext; do
    if ! echo "$core" | grep -qxF "$ext" && echo "$rendered" | grep -qxF "install_extension \"$ext\""; then
      echo "Per-module extension '$ext' rendered without its module being selected" >&2
      return 1
    fi
  done < <(yq -r '.vscode.modules // {} | to_entries[] | .value.extensions // [] | .[]' \
    "$REPO_ROOT/.chezmoidata/packages.yaml")
}
