#!/bin/sh

# Install the pi coding agent (https://pi.dev) with its official installer,
# https://pi.dev/install.sh, the managed install that pi's README recommends.
# Unlike a plain npm install, it pins every dependency (pi publishes an
# npm-shrinkwrap.json), keeps each release under ~/.pi/agent/install, and lets
# `pi update` upgrade it. It needs no root; with ~/.local/bin first on PATH it
# links its launcher there, so it neither asks to edit a shell config nor
# prints a PATH step.
#
# The installer looks for node and npm on PATH and needs Node.js 22.19 or newer.
# `fnm exec` puts fnm's default Node there; install-node.sh sets it up, and the
# after_ prefix and the name order run this script after it.
#
# It runs unattended where there is no controlling terminal (CI, containers).
# At a terminal it shows one install menu on /dev/tty, which Enter accepts; no
# redirection can hide /dev/tty. Its output goes to a file, not the terminal,
# because the installer offers to start pi when stdout is a terminal, and
# accepting would run pi in the middle of the apply.
#
# A plain run_ script, not run_onchange_: an install skipped for want of Node
# is retried on the next apply instead of being recorded as done. The check
# below keeps every later apply instant.

set -eu

# The launcher directory the installer picks first, which the fish config puts
# on PATH but this script's environment may not. The installer takes the first
# of its known launcher dirs (~/.local/bin, ~/bin, ...) in PATH order; fnm exec
# prepends only its Node bin dir, which is not one of them, so ~/.local/bin
# still wins.
PATH="$HOME/.local/bin:$PATH"

url="https://pi.dev/install.sh"

# Any pi already on PATH serves the module, whatever installed it.
if command -v pi > /dev/null 2>&1; then
  exit 0
fi

for tool in fnm bash curl; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "pi: its installer needs ${tool}, so pi is not installed this time; install ${tool} and run 'chezmoi apply' again, or deselect the pi module." >&2
    exit 0
  fi
done

# The minimum the installer checks for; failing here skips without an error.
node_ok() {
  version=$(fnm exec --using=default node --version 2> /dev/null) || return 1
  version=${version#v}
  major=${version%%.*}
  minor=${version#*.}
  minor=${minor%%.*}
  case "$major.$minor" in
  *[!0-9.]* | .* | *.) return 1 ;;
  esac
  [ "$major" -gt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -ge 19 ]; }
}

if ! node_ok; then
  echo "pi: it needs Node.js 22.19 or newer as fnm's default (fnm install --lts; fnm default lts-latest), so pi is not installed this time." >&2
  exit 0
fi

installer=$(mktemp)
log=$(mktemp)
trap 'rm -f "$installer" "$log"' EXIT

# Through a file, not a pipe: sh has no pipefail, and a failed download would
# otherwise run a partial script.
if ! curl -fsSL -o "$installer" "$url"; then
  echo "pi: could not download the installer from ${url}." >&2
  exit 1
fi

# Its output is held until it ends, so a key prompt on /dev/tty would look like
# a hang without this line.
echo "Installing pi with its installer; at a terminal it may wait for a key: press Enter to accept its default install."
status=0
fnm exec --using=default bash "$installer" < /dev/null > "$log" 2>&1 || status=$?
cat "$log"
exit "$status"
