#!/bin/sh

# This script installs harlequin, a SQL client in the terminal, as a uv tool.
# The postgres extra adds the Postgres adapter; DuckDB is built in.
# https://harlequin.sh/docs/getting-started

# -e: exit on error
# -u: exit on unset variables
set -eu

UV_CMD=uv
if ! command -v uv > /dev/null 2>&1; then
  UV_CMD="${HOME}/.local/bin/uv"
fi

# --upgrade also moves an existing install to the latest release.
"$UV_CMD" tool install --upgrade 'harlequin[postgres]'
