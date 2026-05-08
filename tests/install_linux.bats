#!/usr/bin/env bats
# Tests for .chezmoiscripts/linux/run_onchange_install-gh.sh

setup() {
  load 'helpers/setup'
}

@test "gh install script exists and shellchecks" {
  test -f "$REPO_ROOT/.chezmoiscripts/linux/run_onchange_install-gh.sh"
  shellcheck "$REPO_ROOT/.chezmoiscripts/linux/run_onchange_install-gh.sh"
}

@test "gh install script is a no-op if gh is already present" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"

  # Fake gh binary — simulates gh already being installed
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/gh"
  chmod +x "$fake_bin/gh"

  # Fake curl that fails — if the script calls it, the test will catch the failure
  printf '#!/bin/sh\necho "curl should not be called" >&2; exit 1\n' > "$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  run env PATH="$fake_bin:$PATH" HOME="$BATS_TEST_TMPDIR" \
    bash "$REPO_ROOT/.chezmoiscripts/linux/run_onchange_install-gh.sh"
  [ "$status" -eq 0 ]
}
