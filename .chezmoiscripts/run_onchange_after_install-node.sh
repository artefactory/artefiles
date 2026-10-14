#!/bin/sh
# Install the current Node.js LTS with fnm and make it the default, so the nvim
# language servers (Mason) and prettier find node and npm. fnm comes from
# Homebrew on macOS and from the chezmoi external in ~/.local/bin on Linux; the
# after_ prefix runs this once both are in place.
set -eu

PATH="$HOME/.local/bin:$PATH"

if ! command -v fnm > /dev/null 2>&1; then
  echo "fnm is not installed: skipping the Node.js install." >&2
  exit 0
fi

echo "Installing Node.js LTS with fnm..."
fnm install --lts
fnm default lts-latest
echo "Node.js $(fnm exec --using=default node --version) is the default."
