#!/bin/sh
# Installs recommended VSCode extensions if the `code` CLI is available.
# Uses run_onchange so it re-runs when this file changes (e.g. when adding
# extensions to the list below).
# Uses after_ prefix to ensure it runs after brew has installed VSCode.

set -eu

if ! command -v code > /dev/null 2>&1; then
  echo "VSCode CLI (code) not found. Install VSCode and re-run 'chezmoi apply' to install extensions."
  exit 1
fi

install_extension() {
  # Capture extension list once per call; fail loudly if code is broken
  if ! installed=$(code --list-extensions 2>&1); then
    echo "ERROR: 'code --list-extensions' failed: $installed" >&2
    return 1
  fi
  # Use fixed-string matching to avoid treating dots in IDs as regex wildcards
  if echo "$installed" | grep -qiF "$1"; then
    echo "Already installed: $1"
  else
    echo "Installing: $1"
    if ! code --install-extension "$1"; then
      echo "ERROR: Failed to install extension '$1'. Check your network connection and re-run 'chezmoi apply'." >&2
      return 1
    fi
  fi
}

# Theme
install_extension "Catppuccin.catppuccin-vsc"
install_extension "Catppuccin.catppuccin-vsc-icons"

# Python
install_extension "ms-python.python"
install_extension "ms-python.vscode-pylance"
install_extension "charliermarsh.ruff"
