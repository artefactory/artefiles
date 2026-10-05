#!/bin/sh
# Offer to star artefactory/artefiles. install.sh runs this after the default
# shell offer, once chezmoi has finished.
#
# An empty answer (Enter), "y" or "yes", read from the terminal, accepts; any
# other answer, or input that ends, declines. The
# offer is skipped silently when nobody can answer (CI, Codespaces, no
# terminal), when gh is missing, when the repository is already starred, or when
# GitHub answers anything but "not starred". Every path exits 0, so a refusal or
# a failure here never fails the install.
#
# ARTEFILES_TTY only exists so tests can feed an answer.

set -eu

repo="artefactory/artefiles"
tty_dev="${ARTEFILES_TTY:-/dev/tty}"

command -v gh > /dev/null 2>&1 || exit 0

if [ -n "${CI:-}" ] || [ -n "${CODESPACES:-}" ] || ! ( : < "$tty_dev" ) 2> /dev/null; then
  exit 0
fi

# gh exits 0 when the repository is starred and prints "HTTP 404" when it is
# not; any other failure (network, auth) must not trigger a prompt.
if err=$(gh api "user/starred/${repo}" 2>&1 > /dev/null); then
  exit 0
fi
case "$err" in
  *"HTTP 404"*) ;;
  *) exit 0 ;;
esac

print_manual() {
  cat >&2 << MANUAL

To star ${repo} later, open https://github.com/${repo} or run:
  gh api -X PUT user/starred/${repo}
MANUAL
}

printf '\nEnjoying artefiles? Star %s on GitHub? [Y/n] ' "$repo" >&2
answer=""
IFS= read -r answer < "$tty_dev" || answer="n"

case "$answer" in
  "" | y | Y | yes | YES | Yes) ;;
  *)
    print_manual
    exit 0
    ;;
esac

if gh api -X PUT "user/starred/${repo}" > /dev/null 2>&1; then
  echo "Thanks for starring ${repo}!" >&2
else
  echo "Could not star ${repo}." >&2
  print_manual
fi
