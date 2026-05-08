#!/bin/sh
# Install GitHub CLI (gh) via tarball — cross-distro, no root required.

set -eu

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if command -v gh > /dev/null 2>&1; then
  echo "gh is already installed, skipping..."
  exit 0
fi

echo "Installing GitHub CLI..."

latest_version=$(curl -s https://api.github.com/repos/cli/cli/releases/latest \
  | grep '"tag_name":' \
  | sed -E 's/.*"v([^"]+)".*/\1/')

arch=$(uname -m)
case "${arch}" in
  x86_64)         arch_name="amd64" ;;
  aarch64|arm64)  arch_name="arm64" ;;
  *)
    printf 'Unsupported architecture: %s\n' "${arch}" >&2
    exit 1
    ;;
esac

download_url="https://github.com/cli/cli/releases/download/v${latest_version}/gh_${latest_version}_linux_${arch_name}.tar.gz"
tmp_dir=$(mktemp -d)
curl -sL "${download_url}" | tar xz -C "${tmp_dir}"
cp "${tmp_dir}"/gh_*/bin/gh "$HOME/.local/bin/gh"
rm -rf "${tmp_dir}"

echo "GitHub CLI installed successfully"
