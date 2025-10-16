#!/bin/sh

# Install Git for Linux
# Designed for user-level installation without root privileges where possible

set -eu

# Install Git if not already installed (if not available, skip as it's likely system-provided)
if ! command -v git > /dev/null 2>&1; then
  echo "Git not found. On Linux systems, Git should be installed by the system administrator."
  echo "Skipping Git installation."
else
  echo "Git is already installed."
fi

# Git LFS is now managed by chezmoiexternal.toml
if command -v git-lfs > /dev/null 2>&1; then
  echo "Git LFS is installed."

  # Install Git LFS hooks
  if command -v git > /dev/null 2>&1; then
    git lfs install --skip-repo
  fi
else
  echo "Git LFS is not installed yet (will be installed by chezmoi external)."
fi
