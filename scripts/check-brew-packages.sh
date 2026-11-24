#!/bin/sh
# Check that every Homebrew package of every module exists, without installing.
#
# A formula that moves to a cask (azure-cli, #280) or is renamed makes
# `brew bundle` fail on a user's Mac, and the bats suite only greps the
# rendered text. This asks Homebrew itself, for the core list and for every
# module, selected or not.
#
# usage: check-brew-packages.sh [packages.yaml]
# Exit 0 when all exist; 1 when some are missing (all are listed) or the check
# cannot run (no yq, unreadable file, failed tap); 2 only when brew info failed
# for a reason other than "not found" (INCONCLUSIVE, nothing missing). A caller
# treats 2 as a warning, not a failure.
set -eu

# A check must not wait on a Homebrew self-update.
export HOMEBREW_NO_AUTO_UPDATE=1

here=$(cd "$(dirname "$0")" && pwd)
file=${1:-"$here/../.chezmoidata/packages.yaml"}

command -v brew > /dev/null 2>&1 || {
  echo "ERROR: brew is required" >&2
  exit 1
}
command -v yq > /dev/null 2>&1 || {
  echo "ERROR: yq is required: install it with brew install yq" >&2
  exit 1
}
[ -r "$file" ] || {
  echo "ERROR: cannot read $file" >&2
  exit 1
}

# A package named owner/tap/name only resolves once its tap is added.
for tap in $(yq -r '.packages.darwin.modules[].taps // [] | .[]' "$file"); do
  brew tap "$tap" > /dev/null 2>&1 || {
    echo "ERROR: cannot add tap $tap" >&2
    exit 1
  }
done

missing=0
inconclusive=0
total=0
# Seconds before the single retry; tests set it to 0.
SLEEP=${SLEEP:-2}

# exists KIND NAME: 0 when Homebrew knows the package, 1 when it says it does
# not, 3 when brew failed for another reason (network, rate limit, crash), with
# its first error line in $err. Since Homebrew 6 brew refuses to load a
# third-party tap's package until it is trusted, and trusting it would change
# the machine's settings, so for those the tap's own files are read.
exists() {
  attempt=1
  while :; do
    if out=$(brew info "--$1" "$2" 2>&1); then
      return 0
    fi
    case "$out" in
      *"untrusted tap"*)
        tap=${2%/*}
        dir=$(brew --repository "$tap" 2> /dev/null) || return 1
        [ -n "$(find "$dir" -name "${2##*/}.rb" -path "*/$([ "$1" = cask ] && echo Casks || echo Formula)/*" 2> /dev/null | head -1)" ]
        return
        ;;
      *"No available formula"* | *"No available cask"* | *"No formulae or casks found"*) return 1 ;;
    esac
    # Anything else may be a Homebrew or network outage, which says nothing
    # about the package: retry once, then report it as inconclusive.
    [ "$attempt" -lt 2 ] || break
    attempt=$((attempt + 1))
    sleep "$SLEEP"
  done
  err=$(printf '%s\n' "$out" | head -1)
  return 3
}

check() { # kind name
  total=$((total + 1))
  rc=0
  exists "$1" "$2" || rc=$?
  [ "$rc" -ne 0 ] || return 0
  if [ "$rc" -eq 3 ]; then
    echo "INCONCLUSIVE $2: $err"
    inconclusive=$((inconclusive + 1))
    return 0
  fi
  other=cask
  [ "$1" = formula ] || other=formula
  rc=0
  exists "$other" "$2" || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "MISSING $1 $2 (it exists as a $other: declare it there)"
  else
    echo "MISSING $1 $2"
  fi
  missing=$((missing + 1))
}

for n in $(yq -r '.packages.darwin.core.brews[], (.packages.darwin.modules[].brews[])' "$file"); do
  check formula "$n"
done
for n in $(yq -r '.packages.darwin.core.casks[], (.packages.darwin.modules[].casks[])' "$file"); do
  check cask "$n"
done

echo "checked $total packages, $missing missing, $inconclusive inconclusive"
[ "$missing" -eq 0 ] || exit 1
[ "$inconclusive" -eq 0 ] || exit 2
