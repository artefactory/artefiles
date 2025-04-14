#!/bin/sh

# Install Git and Git LFS for Linux
# Designed for user-level installation without root privileges where possible

set -eu

# Install Git if not already installed (if not available, skip as it's likely system-provided)
if ! command -v git > /dev/null 2>&1; then
  echo "Git not found. On Linux systems, Git should be installed by the system administrator."
  echo "Skipping Git installation."
else
  echo "Git is already installed."
fi

# Install Git LFS if not already installed
if ! command -v git-lfs > /dev/null 2>&1; then
  echo "Installing Git LFS..."

  # Set up directories
  INSTALL_DIR="${HOME}/.local"
  BIN_DIR="${INSTALL_DIR}/bin"
  mkdir -p "${BIN_DIR}"

  # Define fallback version for API rate limit case
  FALLBACK_VERSION="3.4.0"

  # Try to get the latest release version
  echo "Attempting to get latest Git LFS version..."
  GITHUB_RESPONSE=$(curl -s https://api.github.com/repos/git-lfs/git-lfs/releases/latest)

  # Check if the API rate limit was exceeded
  if echo "$GITHUB_RESPONSE" | grep -q "API rate limit exceeded"; then
    echo "GitHub API rate limit exceeded. Using fallback version ${FALLBACK_VERSION}."
    LATEST_RELEASE="$FALLBACK_VERSION"
  else
    LATEST_RELEASE=$(echo "$GITHUB_RESPONSE" | grep '"tag_name":' | sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/')

    # If failed to get the latest version for any reason other than rate limit, exit
    if [ -z "$LATEST_RELEASE" ]; then
      echo "ERROR: Failed to determine latest version from GitHub API."
      exit 1
    else
      echo "Found latest Git LFS version: ${LATEST_RELEASE}"
    fi
  fi

  # Create temporary directory
  TEMP_DIR=$(mktemp -d)
  cd "${TEMP_DIR}"

  # Detect architecture
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then
    ARCH_NAME="amd64"
  elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH_NAME="arm64"
  else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
  fi

  # Download and extract
  DOWNLOAD_URL="https://github.com/git-lfs/git-lfs/releases/download/v${LATEST_RELEASE}/git-lfs-linux-${ARCH_NAME}-v${LATEST_RELEASE}.tar.gz"
  echo "Downloading Git LFS from ${DOWNLOAD_URL}..."

  if ! curl -fLo git-lfs.tar.gz "$DOWNLOAD_URL"; then
    echo "ERROR: Failed to download Git LFS from ${DOWNLOAD_URL}"
    exit 1
  fi
  tar -xzf git-lfs.tar.gz

  # Install
  cp -f git-lfs-*/git-lfs "${BIN_DIR}/"

  # Clean up
  cd - > /dev/null
  rm -rf "${TEMP_DIR}"

  # Install Git LFS hooks
  if command -v git > /dev/null 2>&1; then
    "${BIN_DIR}/git-lfs" install --skip-repo
  fi

  echo "Git LFS has been installed to ${BIN_DIR}/git-lfs"
else
  echo "Git LFS is already installed."
fi
