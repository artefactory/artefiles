#!/bin/sh

# Install WezTerm CLI components for remote Linux servers (non-GUI)
# https://github.com/wez/wezterm

set -eu

echo "Installing WezTerm CLI components..."

# Set directories
INSTALL_DIR="${HOME}/.local"
BIN_DIR="${INSTALL_DIR}/bin"
SHARE_DIR="${INSTALL_DIR}/share"
mkdir -p "${BIN_DIR}" "${SHARE_DIR}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

# Determine architecture
ARCH=$(uname -m)

# Get latest stable release information
echo "Determining latest WezTerm stable release..."
GITHUB_RESPONSE=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest)

# Check if the API rate limit was exceeded
if echo "$GITHUB_RESPONSE" | grep -q "API rate limit exceeded"; then
  echo "GitHub API rate limit exceeded. Using fallback version."
  LATEST_VERSION="20240203-110809-5046fc22"
else
  LATEST_VERSION=$(echo "$GITHUB_RESPONSE" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  
  # Remove "v" prefix if present
  LATEST_VERSION=${LATEST_VERSION#v}
  
  # If failed to get the latest version for any reason, use the fallback
  if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to determine latest version. Using fallback version."
    LATEST_VERSION="20240203-110809-5046fc22"
  fi
fi

echo "Using WezTerm version: $LATEST_VERSION"

# Download the WezTerm stable release
echo "Downloading WezTerm stable release..."
DOWNLOAD_URL="https://github.com/wez/wezterm/releases/download/$LATEST_VERSION/wezterm-$LATEST_VERSION.Ubuntu20.04.tar.xz"
echo "Download URL: $DOWNLOAD_URL"

curl -fsSL -o wezterm.tar.xz "$DOWNLOAD_URL" || { 
  echo "ERROR: Failed to download WezTerm stable release"
  exit 1
}

# Extract the tarball
echo "Extracting WezTerm files..."
tar -xJf wezterm.tar.xz || {
  echo "ERROR: Failed to extract WezTerm tarball"
  exit 1
}

# Find the wezterm binaries
echo "Looking for WezTerm binaries in extracted directory structure..."
find . -name "wezterm" -o -name "wezterm-mux-server" -o -name "strip-ansi-escapes" | sort

# Check if binaries exist in usr/bin (Debian package structure)
if [ -d "usr/bin" ]; then
  echo "Found usr/bin directory, using binaries from there"
  
  # Copy the binaries from usr/bin
  cp -f usr/bin/wezterm "${BIN_DIR}/" || { echo "ERROR: Failed to copy wezterm binary from usr/bin"; exit 1; }
  cp -f usr/bin/wezterm-mux-server "${BIN_DIR}/" || { echo "ERROR: Failed to copy wezterm-mux-server binary from usr/bin"; exit 1; }
  cp -f usr/bin/strip-ansi-escapes "${BIN_DIR}/" || { echo "ERROR: Failed to copy strip-ansi-escapes binary from usr/bin"; exit 1; }
else
  # Try to find the binaries anywhere in the extracted directory
  wezterm_bin=$(find . -name "wezterm" -type f | head -1)
  wezterm_mux_bin=$(find . -name "wezterm-mux-server" -type f | head -1)
  strip_ansi_bin=$(find . -name "strip-ansi-escapes" -type f | head -1)

  if [ -z "$wezterm_bin" ] || [ -z "$wezterm_mux_bin" ] || [ -z "$strip_ansi_bin" ]; then
    echo "ERROR: Could not find all required WezTerm binaries"
    exit 1
  fi

  echo "Found binaries at custom locations:"
  echo "wezterm: $wezterm_bin"
  echo "wezterm-mux-server: $wezterm_mux_bin"  
  echo "strip-ansi-escapes: $strip_ansi_bin"

  # Copy the binaries from their found locations
  cp -f "$wezterm_bin" "${BIN_DIR}/" || { echo "ERROR: Failed to copy wezterm binary"; exit 1; }
  cp -f "$wezterm_mux_bin" "${BIN_DIR}/" || { echo "ERROR: Failed to copy wezterm-mux-server binary"; exit 1; }
  cp -f "$strip_ansi_bin" "${BIN_DIR}/" || { echo "ERROR: Failed to copy strip-ansi-escapes binary"; exit 1; }
fi

# Copy shell integration assets for terminal integration
if [ -d shell-integration ]; then
  mkdir -p "${SHARE_DIR}/wezterm"
  cp -f shell-integration/* "${SHARE_DIR}/wezterm/" || echo "Warning: shell integration files not copied"
fi

# Copy terminfo for proper terminal behavior
if [ -d terminfo ]; then
  mkdir -p "${SHARE_DIR}/terminfo"
  cp -rf terminfo/* "${SHARE_DIR}/terminfo/" || echo "Warning: terminfo files not copied"
fi

# Clean up
cd - > /dev/null
rm -rf "${TEMP_DIR}"

echo "WezTerm CLI components installed to ${BIN_DIR}/wezterm"
echo "These components can be used for multiplexing and remote integration."
echo "Make sure ${BIN_DIR} is in your PATH."
