#!/bin/sh
# One report to debug an install or an update: tool versions, the source's
# release and state, GitHub access, chezmoi's own checks, drift, dotfiles_doctor
# failures and the install backups. Changes nothing.
set -eu

section() { printf '\n## %s\n' "$1"; }
version() {
  if command -v "$1" > /dev/null 2>&1; then
    printf '  %-8s %s\n' "$1" "$("$1" --version 2>&1 | head -n 1)"
  else
    printf '  %-8s not installed\n' "$1"
  fi
}

section "Tools"
for t in chezmoi fish git gh brew; do version "$t"; done

section "Source"
if src=$(chezmoi source-path 2> /dev/null); then
  echo "  path: $src"
  if git -C "$src" rev-parse > /dev/null 2>&1; then
    ref=$(git -C "$src" describe --tags --exact-match 2> /dev/null \
      || git -C "$src" symbolic-ref -q --short HEAD 2> /dev/null || echo "detached, not on a release tag")
    echo "  at: $ref"
    echo "  origin: $(git -C "$src" remote get-url origin 2> /dev/null || echo none)"
    dirty=$(git -C "$src" status --porcelain | wc -l | tr -d ' ')
    [ "$dirty" -eq 0 ] || echo "  uncommitted edits: $dirty (they block chezmoi update)"
  fi
else
  echo "  chezmoi has no source: artefiles is not installed."
fi

section "GitHub"
if command -v gh > /dev/null 2>&1 && gh auth status > /dev/null 2>&1; then
  echo "  gh: logged in"
else
  echo "  gh: not logged in (gh auth login)"
fi
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "  GITHUB_TOKEN: unset. Rendering the Linux downloads can hit the API rate limit:"
  echo "    export GITHUB_TOKEN=\"\$(gh auth token)\""
fi

section "chezmoi doctor (problems only)"
chezmoi doctor 2> /dev/null | grep -E '^(warning|error|failed)' | sed 's/^/  /' || echo "  none"

section "Drift"
count=$(chezmoi status --exclude=scripts,externals 2> /dev/null | wc -l | tr -d ' ')
echo "  $count target(s) differ from the source (details: scripts/drift.sh)"

section "dotfiles_doctor (problems only)"
if command -v fish > /dev/null 2>&1 && fish -c 'functions -q dotfiles_doctor' 2> /dev/null; then
  fish -c dotfiles_doctor 2>&1 | grep -E '✗|!' | sed 's/^/  /' || echo "  none"
else
  echo "  not available (fish or dotfiles_doctor missing)"
fi

section "Install backups"
found=0
for b in "${XDG_STATE_HOME:-$HOME/.local/state}"/artefiles/backup-*; do
  [ -d "$b" ] || continue
  echo "  $b (undo the install: sh install.sh --restore $b)"
  found=1
done
[ "$found" -eq 1 ] || echo "  none"
