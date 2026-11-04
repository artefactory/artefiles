#!/bin/sh

# Install Visual Studio Code on Linux from Microsoft's apt repository, as
# https://code.visualstudio.com/docs/setup/linux describes. Once installed,
# the system's apt upgrades keep it current.
#
# A plain run_ script, not run_onchange_: a skipped install (no sudo, no
# terminal) is retried on the next apply instead of being recorded as done.
# The checks below keep every later apply instant.

set -eu

docs="https://code.visualstudio.com/docs/setup/linux"

# Any `code` already on PATH serves the vscode module: the app itself, the
# remote CLI of a Remote-SSH session, or the user's own install.
if command -v code > /dev/null 2>&1; then
  exit 0
fi

# A desktop app needs a desktop. A server, a container or a Codespace reaches
# VS Code through a tunnel instead, which the code_cli module provides.
if [ -n "${CODESPACES:-}" ] || { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; }; then
  echo "VS Code: no graphical session here, so the desktop app is skipped; the code_cli module gives 'code-cli tunnel' to open this machine from VS Code." >&2
  exit 0
fi

if ! command -v apt-get > /dev/null 2>&1; then
  echo "VS Code: this system has no apt-get; install it as ${docs} shows, or deselect the vscode module." >&2
  exit 0
fi

# The package needs root. Without a cached sudo or a terminal to ask for a
# password, the apply goes on and the install waits for the next one.
if [ "$(id -u)" -eq 0 ]; then
  as_root() { "$@"; }
elif command -v sudo > /dev/null 2>&1 && { sudo -n true 2> /dev/null || [ -t 0 ]; }; then
  as_root() { sudo "$@"; }
else
  echo "VS Code needs administrator rights (sudo) to install; run 'chezmoi apply' at a terminal, install it as ${docs} shows, or deselect the vscode module." >&2
  exit 0
fi

# apt-get update fails on any broken source, often one unrelated to VS Code.
# This script retries on every apply, so failing here would block every apply:
# skip until the next one instead. A failed install of code itself still fails.
apt_update() {
  as_root env DEBIAN_FRONTEND=noninteractive apt-get update -q && return 0
  echo "VS Code: 'apt-get update' failed, so VS Code is not installed this time; fix the apt sources and run 'chezmoi apply' again." >&2
  exit 0
}

key_url="https://packages.microsoft.com/keys/microsoft.asc"
key=$(mktemp)
trap 'rm -f "$key" "$key.gpg"' EXIT

echo "Installing VS Code from Microsoft's apt repository..."
apt_update
as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y gpg

# Through files, not a pipe: sh has no pipefail, and a failed download would
# otherwise install an empty key.
if ! curl --retry 5 --retry-delay 2 -fsSL -o "$key" "$key_url"; then
  echo "VS Code: could not download Microsoft's signing key from ${key_url}." >&2
  exit 1
fi
gpg --dearmor < "$key" > "$key.gpg"
# The key and source paths are those of the official instructions, so the
# repository is the one a manual install would set up.
as_root tee /usr/share/keyrings/microsoft.gpg < "$key.gpg" > /dev/null
as_root tee /etc/apt/sources.list.d/vscode.sources > /dev/null << 'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

apt_update
as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y code
