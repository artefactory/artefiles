#!/bin/sh

# This script installs kubectl on Linux in ~/.local/bin, without root.
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

# -e: exit on error
# -u: exit on unset variables
set -eu

STABLE=$(curl -fsSL https://dl.k8s.io/release/stable.txt)

# An installed copy at the stable version needs no download.
if command -v kubectl > /dev/null 2>&1 \
  && [ "$(kubectl version --client 2> /dev/null | sed -n 's/^Client Version: //p')" = "$STABLE" ]; then
  echo "kubectl $STABLE is already installed."
  exit 0
fi

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *)
    echo "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

echo "Installing kubectl $STABLE..."
mkdir -p "${HOME}/.local/bin"
curl -fsSL -o "${HOME}/.local/bin/kubectl" "https://dl.k8s.io/release/${STABLE}/bin/linux/${ARCH}/kubectl"
chmod +x "${HOME}/.local/bin/kubectl"
