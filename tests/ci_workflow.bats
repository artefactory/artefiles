#!/usr/bin/env bats
# The bats-linux job must never report a missing chezmoi as passing.

setup() {
  load 'helpers/setup'
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
}

# install_step — the shell of the "install chezmoi" step of bats-linux.
install_step() {
  yq -r '.jobs."bats-linux".steps[] | select(.name == "install chezmoi") | .run' "$CI_YML"
}

@test "the installer is not run from an empty command substitution" {
  [ -n "$(install_step)" ]
  if install_step | grep -v '^[[:space:]]*#' | grep -qF 'sh -c "$(curl'; then return 1; fi
}

@test "the step fails when chezmoi is not installed afterwards" {
  last=$(install_step | grep -v '^[[:space:]]*$' | tail -1)
  [[ "$last" =~ chezmoi\"?\ --version ]]
}
