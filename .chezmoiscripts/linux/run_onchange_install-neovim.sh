#!/bin/bash
# Script: run_onchange_install-neovim.sh
# Description: Installs or updates Neovim using AppImage distribution method
# Requirements:
#   - Linux x86_64
#   - curl
#   - Optional: FUSE support for direct AppImage execution
set -eu

# Check if FUSE is available on the system
# Returns:
#   0 if FUSE is available
#   1 if FUSE is not available
check_fuse() {
  if command -v fusermount > /dev/null 2>&1 && grep -q fuse /proc/filesystems; then
    return 0
  else
    return 1
  fi
}

# Get the latest available version from GitHub
get_latest_version() {
  local is_legacy=$1
  local repo="neovim/neovim"
  [ "$is_legacy" = "true" ] && repo="neovim/neovim-releases"

  local API_RESPONSE
  API_RESPONSE=$(curl -s "https://api.github.com/repos/${repo}/releases/latest")
  local VERSION
  VERSION=$(echo "$API_RESPONSE" | grep -o '"tag_name": "v[^"]*"' | grep -o 'v[0-9.]*')
  if [ -z "$VERSION" ]; then
    VERSION="v0.11.0" # Fallback to known stable version
  fi
  echo "$VERSION"
}

# Get current installed version
get_current_version() {
  nvim --version | head -n1 | grep -o 'v[0-9.]*'
}

# Install or update Neovim using AppImage distribution method
# The function automatically handles:
# - FUSE vs no-FUSE systems
# - Modern (glibc >= 2.12) vs legacy systems
# - GitHub API fallback with stable version
install_or_update_appimage() {
  local install_dir="${HOME}/.local/bin"

  # Extract glibc version using ldd
  local glibc_version
  glibc_version=$(ldd --version | head -n1 | grep -o '[0-9.]*$')
  echo "Detected glibc version: ${glibc_version}"

  # Compare glibc versions using sort -V for proper version comparison
  local is_legacy=false
  if ! printf '%s\n%s\n' "2.34" "$glibc_version" | sort -V | head -n1 | grep -q "^2.34$"; then
    is_legacy=true
  fi

  # Get latest version
  local NVIM_VERSION
  NVIM_VERSION=$(get_latest_version "$is_legacy")

  # For updates, check if we already have the latest version
  if command -v nvim > /dev/null 2>&1; then
    local CURRENT_VERSION
    CURRENT_VERSION=$(get_current_version)
    if [ "$CURRENT_VERSION" = "$NVIM_VERSION" ]; then
      echo "Neovim is already at the latest version ($NVIM_VERSION)"
      return 0
    fi
    echo "Updating Neovim from $CURRENT_VERSION to $NVIM_VERSION"
  else
    echo "Installing Neovim $NVIM_VERSION"
  fi

  # Set download URL based on system compatibility
  local download_url
  if [ "$is_legacy" = "true" ]; then
    echo "Using unsupported binary (glibc < 2.34)"
    download_url="https://github.com/neovim/neovim-releases/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.appimage"
  else
    echo "Using standard AppImage (glibc >= 2.34)"
    download_url="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.appimage"
  fi

  local appimage_path="${install_dir}/nvim.appimage"

  # Download AppImage with error handling
  echo "Downloading Neovim AppImage from ${download_url}..."
  curl -L "${download_url}" -o "${appimage_path}" || {
    echo "Failed to download Neovim AppImage from ${download_url}"
    exit 1
  }
  chmod u+x "${appimage_path}"

  # Handle FUSE vs no-FUSE systems
  if ! check_fuse; then
    echo "FUSE is not available, extracting AppImage..."
    cd "${install_dir}"
    local extract_dir="${install_dir}/nvim-extracted"
    # Clean up old extracted version if it exists
    [ -d "${extract_dir}" ] && rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}"

    # Extract AppImage contents to directory (cd first to extract in the right location)
    cd "${extract_dir}"
    "${appimage_path}" --appimage-extract || {
      echo "Failed to extract AppImage (check disk space and permissions)"
      exit 1
    }
    ln -sf "${extract_dir}/squashfs-root/usr/bin/nvim" "${install_dir}/nvim"
    rm -f "${appimage_path}" # Remove AppImage after successful extraction
  else
    echo "FUSE is available, using AppImage directly"
    ln -sf "${appimage_path}" "${install_dir}/nvim"
  fi

  # Verify installation succeeded
  "${install_dir}/nvim" --version || {
    echo "Failed to verify Neovim installation (expected ${NVIM_VERSION})"
    exit 1
  }
  echo "Neovim ${NVIM_VERSION} installation completed successfully"
}

# Create required directories if they don't exist
mkdir -p "${HOME}/.local/bin"        # For the binary
mkdir -p "${HOME}/.local/share/nvim" # For plugins and data
mkdir -p "${HOME}/.config/nvim"      # For configuration

# Install or update Neovim
install_or_update_appimage
