#!/bin/sh
set -eu

# Install the standalone GitHub Copilot CLI via the official installer.
# https://github.com/github/copilot-cli — the gh.io/copilot-install URL
# is the maintainer-published one-shot installer; it picks the right
# binary for the host arch and drops it on PATH.
# An installed copy at the latest release needs no download.
latest=$(curl -fsSL https://api.github.com/repos/github/copilot-cli/releases/latest 2> /dev/null \
  | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1)
if [ -n "$latest" ] && command -v copilot > /dev/null 2>&1 \
  && copilot --version 2> /dev/null | grep -qF "$latest"; then
  echo "GitHub Copilot CLI ${latest} is already installed."
  exit 0
fi

echo "Installing GitHub Copilot CLI from gh.io/copilot-install..."
# PREFIX is the installer's documented opt-in for the install location.
# Default for non-root is already $HOME/.local but make it explicit so a
# future change in the upstream default can't silently move our copy.
PREFIX="$HOME/.local" curl -fsSL https://gh.io/copilot-install | bash

echo "GitHub Copilot CLI installed successfully."
