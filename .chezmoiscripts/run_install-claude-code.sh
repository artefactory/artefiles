#!/bin/sh

# Install Claude Code with Anthropic's native installer on the stable channel,
# the command that https://code.claude.com/docs/en/setup gives for macOS and
# Linux:
#   curl -fsSL https://claude.ai/install.sh | bash -s stable
# Stable trails latest by about a week and skips releases with major
# regressions, and the channel chosen at install becomes the default for
# auto-updates. The installer needs no root and puts the launcher at
# ~/.local/bin/claude, a symlink into ~/.local/share/claude/versions/. Native
# installs update themselves, so this script installs once and never upgrades.
#
# A plain run_ script, not run_onchange_: a skipped or failed install is
# retried on the next apply instead of being recorded as done. The check below
# keeps every later apply instant.

set -eu

# The installer's launcher directory, which the fish config puts on PATH but
# this script's environment may not.
PATH="$HOME/.local/bin:$PATH"

url="https://claude.ai/install.sh"

# Any claude already on PATH serves the module, whatever installed it.
if command -v claude > /dev/null 2>&1; then
  exit 0
fi

# Alpine and other minimal systems ship neither by default.
for tool in bash curl; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "Claude Code: its installer needs ${tool}; install ${tool} and run 'chezmoi apply' again, or deselect the claude_code module." >&2
    exit 0
  fi
done

installer=$(mktemp)
trap 'rm -f "$installer"' EXIT

# Through a file, not a pipe: sh has no pipefail, and a failed download would
# otherwise run a partial script.
if ! curl --retry 5 --retry-delay 2 -fsSL -o "$installer" "$url"; then
  echo "Claude Code: could not download the installer from ${url}." >&2
  exit 1
fi

echo "Installing Claude Code with its native installer..."
# Stdin is not a terminal, as with the documented pipe.
bash "$installer" stable < /dev/null
