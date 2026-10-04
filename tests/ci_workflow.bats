#!/usr/bin/env bats
# The bats-linux job must never report a missing chezmoi as passing: the install
# step retries the download and checks that chezmoi runs afterwards.

setup() {
  load 'helpers/setup'
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
}

# install_step — the shell of the "install chezmoi" step of bats-linux.
install_step() {
  yq -r '.jobs."bats-linux".steps[] | select(.name == "install chezmoi") | .run' "$CI_YML"
}

@test "the workflow is valid YAML with a chezmoi install step" {
  [ -n "$(install_step)" ]
}

@test "the installer is not run from an empty command substitution" {
  if install_step | grep -v '^[[:space:]]*#' | grep -qF 'sh -c "$(curl'; then return 1; fi
}

@test "the installer download is retried" {
  step=$(install_step)
  [[ "$step" == *"--retry"* ]]
  [[ "$step" == *"for attempt in"* ]]
}

@test "the step fails when chezmoi is not installed afterwards" {
  last=$(install_step | grep -v '^[[:space:]]*$' | tail -1)
  [[ "$last" =~ chezmoi\"?\ --version ]]
}

@test "the step runs under a shell that stops on the first error" {
  # GitHub's default bash runs with -e and pipefail, but only for an unset shell.
  shell=$(yq -r '.jobs."bats-linux".steps[] | select(.name == "install chezmoi") | .shell // ""' "$CI_YML")
  [ -z "$shell" ] || [[ "$shell" == *"-e"* ]]
}
