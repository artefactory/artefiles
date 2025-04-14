#!/bin/bash
set -eu

install_from_source() {
  local version=$1
  local tmp_dir=$2
  echo "Installing Neovim ${version} from source..."
  
  # Download source code
  cd "${tmp_dir}"
  curl -L "https://github.com/neovim/neovim/archive/refs/tags/${version}.tar.gz" -o nvim-source.tar.gz
  tar xzf nvim-source.tar.gz
  cd "neovim-${version#v}"

  # Build with CMAKE_BUILD_TYPE=RelWithDebInfo for better compatibility
  echo "Building Neovim from source (this may take a while)..."
  make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="${HOME}/.local"
  make install
  cd ..
}

# Install neovim on Linux in user space
if ! command -v nvim > /dev/null 2>&1; then
  echo "Installing neovim..."

  # Create directories
  mkdir -p "${HOME}/.local/bin"
  mkdir -p "${HOME}/.local/share/nvim"
  mkdir -p "${HOME}/.config/nvim"

  # Get latest release from GitHub
  echo "Getting latest Neovim release version..."
if [[ -n "$API_RESPONSE" ]]; then
  NVIM_VERSION=$(echo "$API_RESPONSE" | grep -o '"tag_name": "v[^\"]*"' | grep -o 'v[0-9.]*')
fi

  # Check if we hit API rate limit or extract version or extract version
  if echo "$API_RESPONSE" | grep -q "API rate limit exceeded"; then
    echo "GitHub API rate limit exceeded, using v0.10.4 as fallback."
    NVIM_VERSION="v0.10.4"
  else
    NVIM_VERSION=$(echo "$API_RESPONSE" | grep -o '"tag_name": "v[^"]*"' | grep -o 'v[0-9.]*')
    if [ -z "$NVIM_VERSION" ]; then
      echo "Failed to get latest version from GitHub API, using v0.10.4 as fallback."
      NVIM_VERSION="v0.10.4"
    else
      echo "Latest Neovim version: $NVIM_VERSION"
    fi
  fi

  # Create temporary directory and build from source
  # Create temporary directory and build from source
  TMP_DIR=$(mktemp -d)
  install_from_source "$NVIM_VERSION" "$TMP_DIR"

  # Clean up
  rm -rf "${TMP_DIR}"

  echo "Neovim ${NVIM_VERSION} installed to ${HOME}/.local/bin/nvim"
else
  echo "neovim is already installed."
fi