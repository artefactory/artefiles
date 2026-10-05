#!/bin/sh
# Offer to make fish the login shell. install.sh runs this as its very last
# step, after chezmoi has finished: changing the login shell needs sudo and
# chsh, so it must never run inside `chezmoi apply`, where other steps could
# depend on it or nobody is watching.
#
# An empty answer (Enter), "y" or "yes", read from the terminal, accepts; any
# other answer, or input that ends, declines. Every other path prints the manual commands and exits 0, so a refusal or a
# failure here never fails the install.
#
# ARTEFILES_TTY and ARTEFILES_SHELLS_FILE only exist so tests can feed an
# answer and avoid touching /etc/shells.

set -eu

tty_dev="${ARTEFILES_TTY:-/dev/tty}"
shells_file="${ARTEFILES_SHELLS_FILE:-/etc/shells}"

fish_path=""
for candidate in fish "${HOME}/.local/bin/fish"; do
  if found=$(command -v "$candidate" 2> /dev/null); then
    fish_path="$found"
    break
  fi
done
[ -n "$fish_path" ] || exit 0

case "$(basename "${SHELL:-}")" in
  fish) exit 0 ;;
esac

print_manual() {
  cat >&2 << MANUAL

To make fish your default shell later, run:
  grep -qxF '${fish_path}' ${shells_file} || echo '${fish_path}' | sudo tee -a ${shells_file}
  chsh -s ${fish_path}
MANUAL
}

# CI and Codespaces have nobody to answer, and a missing terminal means nobody
# is watching: never act without both.
if [ -n "${CI:-}" ] || [ -n "${CODESPACES:-}" ] || ! ( : < "$tty_dev" ) 2> /dev/null; then
  print_manual
  exit 0
fi

printf '\nMake fish your default shell? This runs sudo and chsh. [Y/n] ' >&2
answer=""
IFS= read -r answer < "$tty_dev" || answer="n"

case "$answer" in
  "" | y | Y | yes | YES | Yes) ;;
  *)
    print_manual
    exit 0
    ;;
esac

if ! grep -qxF "$fish_path" "$shells_file" 2> /dev/null; then
  if ! printf '%s\n' "$fish_path" | sudo tee -a "$shells_file" > /dev/null; then
    echo "Could not register ${fish_path} in ${shells_file}." >&2
    print_manual
    exit 0
  fi
fi

if chsh -s "$fish_path"; then
  echo "fish is now your default shell. Open a new terminal to use it." >&2
else
  echo "chsh failed; your default shell is unchanged." >&2
  print_manual
fi
