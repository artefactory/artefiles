#!/usr/bin/env bats
# Verify that VSCode extensions are driven by packages.yaml rather than
# hardcoded in the shell script.

setup() {
  load 'helpers/setup'
}

@test "all core yaml extensions appear in rendered install script" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl)
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
  on=$(chezmoi_render "$H_on" .chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl)
  H_off=$(mk_fake_home "$BATS_TEST_TMPDIR/off")
  seed_chezmoi_config "$H_off" '{"modules":[]}'
  off=$(chezmoi_render "$H_off" .chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl)
  for ext in "ms-python.python" "ms-python.vscode-pylance" "charliermarsh.ruff"; do
    echo "$on" | grep -qxF "install_extension \"$ext\""
    if echo "$off" | grep -qxF "install_extension \"$ext\""; then return 1; fi
  done
}

@test "the VS Code app is not installed by the setup" {
  if grep -n 'visual-studio-code' "$REPO_ROOT/.chezmoidata/packages.yaml"; then return 1; fi
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  ! echo "$rendered" | grep -q 'visual-studio-code'
}

@test "docs say VS Code is optional and not installed by the setup" {
  if grep -nE '^Fish, Starship.*VS Code' "$REPO_ROOT/README.md"; then return 1; fi
  grep -qF 'VS Code is not installed by this setup' "$REPO_ROOT/README.md"
  ! grep -nE '^\s*\| Editors \| neovim, vscode' "$REPO_ROOT/CHEATSHEET.md"
}

@test "per-module extensions absent when module not selected" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl)
  core=$(yq -r '.vscode.extensions // [] | .[]' "$REPO_ROOT/.chezmoidata/packages.yaml")
  while IFS= read -r ext; do
    if ! echo "$core" | grep -qxF "$ext" && echo "$rendered" | grep -qxF "install_extension \"$ext\""; then
      echo "Per-module extension '$ext' rendered without its module being selected" >&2
      return 1
    fi
  done < <(yq -r '.vscode.modules // {} | to_entries[] | .value.extensions // [] | .[]' \
    "$REPO_ROOT/.chezmoidata/packages.yaml")
}
