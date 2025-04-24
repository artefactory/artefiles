#!/bin/sh

# Install 1Password CLI (op) for Linux without requiring root
# https://developer.1password.com/docs/cli/

set -eu

# Check if 1Password CLI is already installed
if command -v op > /dev/null 2>&1; then
  echo "1Password CLI (op) already installed."
  echo "Version: $(op --version)"
  exit 0
fi

echo "Installing 1Password CLI..."

# Create temporary directory for the download
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

# Define fallback version in case of API rate limit
FALLBACK_VERSION="2.24.0"

# Try to get the latest release version
GITHUB_RESPONSE=$(curl -s https://api.github.com/repos/1Password/op/releases/latest)

# Check if the API rate limit was exceeded
if echo "$GITHUB_RESPONSE" | grep -q "API rate limit exceeded"; then
  echo "GitHub API rate limit exceeded. Using fallback version ${FALLBACK_VERSION}."
  LATEST_RELEASE="${FALLBACK_VERSION}"
else
  LATEST_RELEASE=$(echo "$GITHUB_RESPONSE" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

  # If failed to get the latest version for any reason, use the fallback
  if [ -z "$LATEST_RELEASE" ]; then
    echo "Failed to determine latest version. Using fallback version ${FALLBACK_VERSION}."
    LATEST_RELEASE="${FALLBACK_VERSION}"
  else
    echo "Found latest 1Password CLI version: ${LATEST_RELEASE}"
  fi
fi

# Detect architecture and OS
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  ARCH_NAME="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  ARCH_NAME="arm64"
else
  echo "Error: Unsupported architecture: $ARCH"
  exit 1
fi

# Set download URL
DOWNLOAD_URL="https://cache.agilebits.com/dist/1P/op/pkg/v${LATEST_RELEASE}/op_linux_${ARCH_NAME}_v${LATEST_RELEASE}.zip"
echo "Downloading 1Password CLI from ${DOWNLOAD_URL}..."

# Download and extract
curl -sS -o op.zip "$DOWNLOAD_URL"
if [ ! -s op.zip ]; then
  echo "Error: Failed to download 1Password CLI from ${DOWNLOAD_URL}"
  exit 1
fi

# Create directory for binaries if needed
mkdir -p "${HOME}/.local/bin"

# Extract directly to the bin directory
unzip -o op.zip op -d "${HOME}/.local/bin/"
chmod +x "${HOME}/.local/bin/op"

# Cleanup
cd - > /dev/null
rm -rf "${TEMP_DIR}"

echo "1Password CLI installed successfully to ${HOME}/.local/bin/op"
echo "Usage: op --help"
echo "For service account creation: op service-account create \"My Service Account\" --can-create-vaults --expires-in 24h --vault Production:read_items,write_items"
