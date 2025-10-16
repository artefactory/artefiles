#!/bin/sh
set -eu

# Check if node and npm are installed
if ! command -v node > /dev/null 2>&1 || ! command -v npm > /dev/null 2>&1; then
  echo "Node.js and npm are required to install the Copilot CLI."
  echo "Please install Node.js v22+ and npm v10+."
  exit 1
fi

# Install copilot-cli
echo "Installing GitHub Copilot CLI..."
npm install -g @github/copilot

echo "GitHub Copilot CLI installed successfully."
