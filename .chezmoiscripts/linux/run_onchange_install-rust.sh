#!/bin/sh

# Install Rust - Programming language and package manager (cargo)
# https://www.rust-lang.org/tools/install

set -eu

echo "Checking Rust installation..."

# Function to install Rust
install_rust() {
  echo "Installing Rust using rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  echo "Rust installed successfully."
}

# Check if rustup is installed
if command -v rustup > /dev/null 2>&1; then
  # rustup check lists each toolchain as "Up to date" or "Update available".
  if rustup check 2> /dev/null | grep -q 'Update available'; then
    echo "Rust is already installed. Updating..."
    rustup update
  else
    echo "Rust is already installed and up to date."
  fi
else
  # Check if rust is installed through another method
  if command -v rustc > /dev/null 2>&1; then
    echo "Rust is installed but not managed by rustup. Installing rustup..."
    install_rust
  else
    # Fresh install
    install_rust
  fi
fi

echo "Rust installation/update completed."
