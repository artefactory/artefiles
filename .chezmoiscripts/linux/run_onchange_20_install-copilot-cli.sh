#!/bin/sh
set -eu

# Install the standalone GitHub Copilot CLI via the official installer.
# https://github.com/github/copilot-cli — the gh.io/copilot-install URL
# is the maintainer-published one-shot installer; it picks the right
# binary for the host arch and drops it on PATH.
echo "Installing GitHub Copilot CLI from gh.io/copilot-install..."
curl -fsSL https://gh.io/copilot-install | bash

echo "GitHub Copilot CLI installed successfully."
