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

@test "refactor preserves the 5 default extensions" {
  exts=$(yq -r '.vscode.extensions[]' "$REPO_ROOT/.chezmoidata/packages.yaml")
  for ext in "Catppuccin.catppuccin-vsc" "Catppuccin.catppuccin-vsc-icons" \
             "ms-python.python" "ms-python.vscode-pylance" "charliermarsh.ruff"; do
    if ! echo "$exts" | grep -qxF "$ext"; then
      echo "Expected extension '$ext' missing from packages.yaml" >&2
      return 1
    fi
  done
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
