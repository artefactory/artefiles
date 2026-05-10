#!/bin/sh

# Install atuin (shell history manager)
# https://docs.atuin.sh/guide/installation/

set -eu

# Check if atuin-upgrade is available (which means atuin is installed)
if command -v atuin-upgrade > /dev/null 2>&1; then
  echo "atuin is installed, running atuin-upgrade to update..."
  atuin-upgrade
else
  echo "Installing atuin using the official installation script..."
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
fi
