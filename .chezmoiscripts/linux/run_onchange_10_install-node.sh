#!/bin/sh
set -eu

# Get the latest nvm version
NVM_LATEST_VERSION=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

# Install nvm
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installing nvm v$NVM_LATEST_VERSION..."
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_LATEST_VERSION/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js LTS
echo "Installing Node.js LTS..."
nvm install --lts

# Install npm
echo "Installing npm..."
nvm install-latest-npm

echo "Node.js and npm installed successfully."
