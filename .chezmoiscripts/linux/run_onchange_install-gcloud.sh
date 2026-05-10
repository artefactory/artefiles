#!/bin/sh

# This script installs Google Cloud SDK on Linux
# https://cloud.google.com/sdk/docs/install#linux

# -e: exit on error
# -u: exit on unset variables
set -eu

# Check if Google Cloud SDK is already installed in our target location
if [ -d "${HOME}/.local/google-cloud-sdk" ]; then
  echo "Google Cloud SDK is already installed at ${HOME}/.local/google-cloud-sdk."
  if [ -f "${HOME}/.local/google-cloud-sdk/bin/gcloud" ]; then
    echo "Version: $("${HOME}"/.local/google-cloud-sdk/bin/gcloud --version | head -n 1)"

    # Create a symlink to make it available in PATH
    mkdir -p "${HOME}/.local/bin"
    ln -sf "${HOME}/.local/google-cloud-sdk/bin/gcloud" "${HOME}/.local/bin/gcloud"
  fi
  exit 0
fi

echo "Installing Google Cloud SDK..."

# Check for Python
if ! command -v python3 > /dev/null 2>&1; then
  echo "Python 3 is required for Google Cloud SDK but not found."
  echo "Please install Python 3.8 to 3.13 before continuing."
  exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
echo "Using Python version: $PYTHON_VERSION"

# Create temp directory for download
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  SDK_ARCHIVE="google-cloud-cli-linux-x86_64.tar.gz"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  SDK_ARCHIVE="google-cloud-cli-linux-arm.tar.gz"
else
  echo "Unsupported architecture: $ARCH. Trying x86_64 version..."
  SDK_ARCHIVE="google-cloud-cli-linux-x86_64.tar.gz"
fi

echo "Downloading Google Cloud SDK for $ARCH..."
curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/$SDK_ARCHIVE"
tar -xf "$SDK_ARCHIVE"

# Create installation directory
INSTALL_DIR="${HOME}/.local/google-cloud-sdk"
mkdir -p "${HOME}/.local"

# Move extracted SDK to destination
mv google-cloud-sdk "$INSTALL_DIR"

# Run installation script with appropriate flags
# Note: We handle PATH updates in our Fish config
echo "Running installation script..."
"$INSTALL_DIR/install.sh" \
  --quiet \
  --usage-reporting=false \
  --command-completion=true \
  --path-update=false \
  --additional-components=gke-gcloud-auth-plugin

# Ensure the environment settings are created for fish
"$INSTALL_DIR/bin/gcloud" init --skip-diagnostics --quiet 2> /dev/null || true

# Clean up
cd - > /dev/null
rm -rf "${TEMP_DIR}"

# Verify installation
if [ -f "$INSTALL_DIR/bin/gcloud" ]; then
  echo "Google Cloud SDK installed successfully!"
  echo "Version: $("$INSTALL_DIR"/bin/gcloud --version | head -n 1)"
else
  echo "WARNING: Installation failed. Check the logs above for errors."
fi

echo "Cloud SDK installed to $INSTALL_DIR"
echo "Path will be configured in Fish shell configuration automatically."
echo "Note: To use 'gcloud' in this session, run: export PATH=\"$INSTALL_DIR/bin:\$PATH\""
