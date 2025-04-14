#!/bin/sh

# Install Fisher (a plugin manager for Fish shell)
# https://github.com/jorgebucaran/fisher
# This script runs after fish is installed on both Linux and macOS platforms

set -eu

# Check if fish is installed
if ! command -v fish > /dev/null 2>&1; then
  echo "Fish shell is not installed. Fisher installation aborted."
  exit 1
fi

# Check if Fisher is already installed
if ! fish -c "functions -q fisher" > /dev/null 2>&1; then
  echo "Installing Fisher plugin manager for Fish shell..."

  # Create the Fisher functions directory if it doesn't exist
  FISHER_FUNCTIONS_DIR="$HOME/.config/fish/functions"
  mkdir -p "$FISHER_FUNCTIONS_DIR"

  # Download the fisher.fish function file
  fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
fi

# Update Fisher plugins (non-installed plugins only)
fish -c "fisher update"
