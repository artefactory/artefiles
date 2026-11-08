#!/bin/bash

set -eu

# Check if Homebrew is installed
if ! command -v brew > /dev/null 2>&1; then
  echo "Installing Homebrew without confirmation..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl --retry 5 --retry-delay 2 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Setup Homebrew in the current shell session
  if [ -d "/opt/homebrew/bin" ]; then
    # For Apple Silicon Macs
    export PATH="/opt/homebrew/bin:$PATH"
  elif [ -d "/usr/local/bin" ]; then
    # For Intel Macs
    export PATH="/usr/local/bin:$PATH"
  fi
fi

# Verify brew is in PATH
if ! command -v brew > /dev/null 2>&1; then
  echo "Homebrew is installed but not in PATH. Attempting to fix..."
  if [ -f "/opt/homebrew/bin/brew" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
  elif [ -f "/usr/local/bin/brew" ]; then
    export PATH="/usr/local/bin:$PATH"
  else
    echo "ERROR: Cannot find brew executable. Please add Homebrew to your PATH manually."
    exit 1
  fi
fi
