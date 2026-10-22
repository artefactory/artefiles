#!/bin/sh

# This script installs the Azure CLI (az) on Linux as a uv tool.
# https://learn.microsoft.com/cli/azure/install-azure-cli
# uv comes from .chezmoiexternal.toml on every Linux install.

# -e: exit on error
# -u: exit on unset variables
set -eu

# --upgrade also moves an existing install to the latest release.
"${HOME}/.local/bin/uv" tool install --upgrade azure-cli
