#!/bin/bash
set -eu

install_from_source() {
  local version=$1
  local tmp_dir=$2
  echo "Installing Neovim ${version} from source..."
  
  # Download source code
  cd "${tmp_dir}"
  curl -L "https://github.com/neovim/neovim/archive/refs/tags/${version}.tar.gz" -o nvim-source.tar.gz || { echo "Failed to download Neovim source"; exit 1; }
  tar xzf nvim-source.tar.gz || { echo "Failed to extract Neovim source"; exit 1; }
  cd "neovim-${version#v}"

  # Build with CMAKE_BUILD_TYPE=RelWithDebInfo for better compatibility
  echo "Building Neovim from source (this may take a while)..."
  make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="${HOME}/.local" || { echo "Failed to build Neovim"; exit 1; }
  make install || { echo "Failed to install Neovim"; exit 1; }
  cd ..
}

# Install neovim on Linux in user space
if ! command -v nvim > /dev/null 2>&1; then
  echo "Installing neovim..."

  # Create directories
  mkdir -p "${HOME}/.local/bin"
  mkdir -p "${HOME}/.local/share/nvim"
  mkdir -p "${HOME}/.config/nvim"

  # Default fallback version
  FALLBACK_VERSION="v0.10.4"

  # Get latest release from GitHub
  echo "Getting latest Neovim release version..."
  API_RESPONSE=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest)
  
  # Try to extract the version number
  NVIM_VERSION=$(echo "$API_RESPONSE" | grep -o '"tag_name": "v[^"]*"' | grep -o 'v[0-9.]*') || true
  if [ -z "$NVIM_VERSION" ]; then
    echo "Error: Could not get latest version number from GitHub API"
    echo "Using fallback version ${FALLBACK_VERSION}"
    NVIM_VERSION="$FALLBACK_VERSION"
  else
    echo "Latest Neovim version: $NVIM_VERSION"
  fi

  # Create temporary directory and build from source
  TMP_DIR=$(mktemp -d)
  install_from_source "$NVIM_VERSION" "$TMP_DIR"

  # Clean up
  rm -rf "${TMP_DIR}"
  echo "Neovim ${NVIM_VERSION} installation completed"
else
  echo "neovim is already installed."
fi