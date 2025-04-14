#!/bin/sh
# Script to install Python development tools using uv
# Installs pre-commit and nbdime on both macOS and Linux
# This script runs last due to "zzzzz" in the name

set -eu

# Function to check if a command exists
command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# Function to check if git hook template exists
template_exists() {
  _hook_type="$1"
  _template_dir="$HOME/.git_template/hooks"
  if [ -f "$_template_dir/$_hook_type" ]; then
    return 0 # File exists
  fi
  return 1 # File doesn't exist
}

# Function to check if nbdime is already configured in git
nbdime_configured() {
  # Check for both diff.jupyternotebook.command and difftool.nbdime.cmd
  if git config --global --get diff.jupyternotebook.command > /dev/null 2>&1 \
    || git config --global --get difftool.nbdime.cmd > /dev/null 2>&1; then
    return 0 # Already configured
  fi
  return 1 # Not configured
}

# Ensure uv is installed first - check both PATH and ~/.local/bin
UV_CMD="uv"
if ! command_exists uv; then
  if [ -x "$HOME/.local/bin/uv" ]; then
    UV_CMD="$HOME/.local/bin/uv"
    echo "Using uv from $HOME/.local/bin"
  else
    echo "uv is required but not installed. Install uv first."
    exit 1
  fi
fi

# Install or update Python tools with a single command
echo "Installing/updating Python development tools..."
"$UV_CMD" tool install --upgrade --force nbdime
"$UV_CMD" tool install --upgrade pre-commit
echo "Python tools installed/updated successfully."

# Initialize pre-commit git template directory
echo "Checking pre-commit git templates..."

# Create template directory if it doesn't exist
mkdir -p "$HOME/.git_template/hooks"

# Check for existing templates and only install missing ones
TEMPLATES="commit-msg pre-commit pre-push"
MISSING_TEMPLATES=""

for template in $TEMPLATES; do
  if ! template_exists "$template"; then
    MISSING_TEMPLATES="$MISSING_TEMPLATES -t $template"
  else
    echo "Git hook template '$template' already exists, skipping"
  fi
done

# Only run init-templatedir if there are missing templates
if [ -n "$MISSING_TEMPLATES" ]; then
  echo "Setting up missing git templates..."
  # Use eval to properly handle the constructed command with multiple -t flags
  eval "pre-commit init-templatedir $MISSING_TEMPLATES $HOME/.git_template"
else
  echo "All git hook templates already exist, skipping installation"
fi

# Set up nbdime git integration only if not already configured
if ! nbdime_configured; then
  echo "Setting up nbdime git integration..."
  # Run nbdime config-git with --global flag first to ensure it affects global gitconfig
  nbdime config-git --global --enable

  # Verify configuration was successful
  if nbdime_configured; then
    echo "Successfully configured nbdime git integration"
  else
    echo "Warning: Failed to configure nbdime git integration"
    # Try alternative approach if the first attempt failed
    nbdime config-git --global --enable --skip-git-and-pip-check
  fi
else
  echo "nbdime git integration already configured, skipping"
fi

echo "Python development tools setup complete."
