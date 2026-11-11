#!/bin/sh
# vim: set ft=bash:
set -eu

# Install git-extras on Linux in user space without root

# Get the latest release version
echo "Checking for the latest git-extras release..."
# curl runs on its own, not in a pipe: without pipefail a pipe takes the status
# of its last command, so a failed request (a rate limit, no network) would
# leave an empty version and the download would fail later on a bad URL.
RELEASE=$(curl --retry 5 --retry-delay 2 -fsS https://api.github.com/repos/tj/git-extras/releases/latest) || {
  echo "Error: failed to fetch the latest git-extras version from the GitHub API." >&2
  exit 1
}
LATEST_VERSION=$(printf '%s\n' "$RELEASE" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_VERSION" ]; then
  echo "Error: the GitHub API answer names no latest git-extras version." >&2
  exit 1
fi
echo "Latest git-extras version: $LATEST_VERSION"

# An installed copy at that version needs no download.
if command -v git-extras > /dev/null 2>&1 \
  && [ "$(git-extras --version 2> /dev/null)" = "${LATEST_VERSION#v}" ]; then
  echo "git-extras ${LATEST_VERSION#v} is already installed."
  exit 0
fi

echo "Installing git-extras..."

# Make sure ~/.local/bin exists
mkdir -p "${HOME}/.local/bin"

# Create a temporary directory for the installation
TMP_DIR=$(mktemp -d)
cd "${TMP_DIR}"

# Download the source tarball
DOWNLOAD_URL="https://github.com/tj/git-extras/archive/refs/tags/${LATEST_VERSION}.tar.gz"
echo "Downloading from $DOWNLOAD_URL"
curl --retry 5 --retry-delay 2 -fL "$DOWNLOAD_URL" -o "git-extras-${LATEST_VERSION}.tar.gz"

# Extract the source
tar -xzf "git-extras-${LATEST_VERSION}.tar.gz"
cd "git-extras-${LATEST_VERSION#v}"

# Use make install with custom PREFIX to install without sudo
# This follows the recommended approach from the official documentation
make install PREFIX="${HOME}/.local"

# Clean up
cd - > /dev/null
rm -rf "${TMP_DIR}"

echo "git-extras has been installed to ${HOME}/.local/bin"
