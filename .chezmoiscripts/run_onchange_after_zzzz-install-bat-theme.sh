#!/bin/bash
set -eu

echo "Installing Catppuccin themes for bat..."

# Check if bat is installed (check both PATH and ~/.local/bin)
BAT_CMD="bat"
if ! command -v bat > /dev/null 2>&1; then
  if [ -x "$HOME/.local/bin/bat" ]; then
    BAT_CMD="$HOME/.local/bin/bat"
  else
    echo "Warning: bat is not installed. Skipping theme installation."
    exit 0
  fi
fi

# Get bat themes directory
BAT_THEMES_DIR="$($BAT_CMD --config-dir)/themes"
mkdir -p "$BAT_THEMES_DIR"

# Define theme names and URLs
THEMES=(
  "Catppuccin Latte"
  "Catppuccin Frappe"
  "Catppuccin Macchiato"
  "Catppuccin Mocha"
)

URLS=(
  "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Latte.tmTheme"
  "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Frappe.tmTheme"
  "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Macchiato.tmTheme"
  "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme"
)

# Check if a theme is already installed
theme_installed() {
  local theme_name="$1"
  local theme_file="$BAT_THEMES_DIR/${theme_name}.tmTheme"

  if [ -f "$theme_file" ]; then
    echo "Theme $theme_name already installed, skipping"
    return 0
  fi
  return 1
}

# Function to download a theme
download_theme() {
  local method="$1"
  local theme_name="$2"
  local url="$3"
  local theme_file="$BAT_THEMES_DIR/${theme_name}.tmTheme"

  # Check if theme is already installed
  if theme_installed "$theme_name"; then
    return 0
  fi

  echo "Downloading $theme_name theme using $method..."

  if [ "$method" = "curl" ]; then
    # Download with curl
    curl -o "$theme_file" -sL "$url"
  elif [ "$method" = "wget" ]; then
    # Download with wget
    wget -q -O "$theme_file" "$url"
  else
    echo "Error: Unknown download method: $method"
    return 1
  fi

  echo "$theme_name theme installed successfully"
  return 0
}

# Determine download method
if command -v wget &> /dev/null; then
  download_method="wget"
elif command -v curl &> /dev/null; then
  download_method="curl"
else
  echo "Error: Neither wget nor curl is available. Please install one of them first."
  exit 1
fi

# Download each theme if not already installed
echo "Checking for Catppuccin themes..."
for i in "${!THEMES[@]}"; do
  download_theme "$download_method" "${THEMES[$i]}" "${URLS[$i]}"
done

# Build bat cache
"$BAT_CMD" cache --build

echo "Catppuccin themes for bat installation completed"
