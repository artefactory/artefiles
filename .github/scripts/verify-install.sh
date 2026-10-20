#!/bin/sh
# Check a finished artefiles install: verify-install.sh EXPECTED_SHA
#
# The source chezmoi uses must be at EXPECTED_SHA, the config must hold the
# answers init stored, the managed files must include the core configuration,
# every file must match what the source renders, and chezmoi doctor must pass.
# Scripts and externals install packages, which CI does not test.
# Every check runs; the script exits 1 when any of them failed.

set -u

expected_sha="${1:?usage: verify-install.sh EXPECTED_SHA}"
failures=0

check() {
  label="$1"
  shift
  if "$@"; then
    echo "ok: ${label}"
  else
    echo "FAILED: ${label}" >&2
    failures=$((failures + 1))
  fi
}

source_at_sha() {
  source_dir="$(chezmoi source-path)" || return 1
  actual="$(git -C "$source_dir" rev-parse HEAD)" || return 1
  echo "source ${source_dir} is at ${actual}"
  [ "$actual" = "$expected_sha" ]
}

config_has_answers() {
  chezmoi data --format=json | jq -e '(.email | type == "string") and (.modules | length > 0)' > /dev/null
}

core_files_managed() {
  managed="$(chezmoi managed --include=files)" || return 1
  for target in .config/fish/config.fish .config/starship.toml .gitconfig; do
    printf '%s\n' "$managed" | grep -qxF "$target" || {
      echo "${target} is not managed" >&2
      return 1
    }
    [ -s "${HOME}/${target}" ] || {
      echo "${HOME}/${target} was not written" >&2
      return 1
    }
  done
}

targets_match_source() {
  chezmoi verify --exclude=scripts,externals
}

doctor_passes() {
  chezmoi doctor --no-network
}

check "the source is at ${expected_sha}" source_at_sha
check "the config holds modules and an email entry (empty under a CI token)" config_has_answers
check "fish, starship and git configs are managed and written" core_files_managed
check "every target matches the source" targets_match_source
check "chezmoi doctor passes" doctor_passes

[ "$failures" -eq 0 ]
