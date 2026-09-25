#!/usr/bin/env bats
# Sandbox behaviour that needs the install features: the module help and the
# alternatives guard, the module checklist, the fish and star offers.

setup() {
  load 'helpers/setup'
  SCRIPT="$REPO_ROOT/sandbox.sh"
  REAL_HOME="$BATS_TEST_TMPDIR/real-home"
  mkdir -p "$REAL_HOME"
}

run_sandbox() {
  run env -u CI -u CODESPACES HOME="$REAL_HOME" XDG_CONFIG_HOME="$REAL_HOME/.config" TMPDIR="$BATS_TEST_TMPDIR" \
    PATH="$PATH" sh "$SCRIPT" "$@"
}

# fake_gh — a gh that says "not starred" and records any star request.
fake_gh() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" << STUB
#!/bin/sh
echo "gh \$*" >> "$BATS_TEST_TMPDIR/gh.calls"
case "\$*" in
  *--jq*login*) echo sandboxer ;;
  *--jq*email*) echo sandboxer@example.com ;;
  "api user/starred/artefactory/artefiles") echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

@test "alternative modules are refused" {
  run_sandbox --modules ghostty,cmux --command 'true'
  [ "$status" -ne 0 ]
  [[ "$output" == *"alternatives"* ]]
}

@test "install.sh in the sandbox shows the offers and stubs every side effect" {
  fake_gh
  for tool in brew curl wget; do
    printf '#!/bin/sh\necho "%s $*" >> "%s/real-tools.calls"\n' "$tool" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bin/$tool"
    chmod +x "$BATS_TEST_TMPDIR/bin/$tool"
  done
  printf '#!/bin/sh\necho "real chsh" >> "%s/real-tools.calls"\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bin/chsh"
  chmod +x "$BATS_TEST_TMPDIR/bin/chsh"
  printf 'y\n' > "$BATS_TEST_TMPDIR/answer"
  : > "$BATS_TEST_TMPDIR/real-tools.calls"
  label=$(prompt_choices | grep '^ghostty | ')
  run env -u CI -u CODESPACES HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" SHELL=/bin/zsh GH_TOKEN=fake \
    ARTEFILES_TTY="$BATS_TEST_TMPDIR/answer" PATH="$BATS_TEST_TMPDIR/bin:$PATH" \
    sh "$SCRIPT" --command 'grep "^modules = " "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"' -- \
    --promptString "Email (default: sandboxer@example.com, press enter to accept)=sandboxer@example.com" \
    --promptMultichoice "Select optional modules=$label"
  [ "$status" -eq 0 ]
  [[ "$output" == *'modules = ["ghostty"]'* ]]
  [[ "$output" == *"Make fish your default shell?"* ]]
  [[ "$output" == *"(sandbox) would run: chsh"* ]]
  [ ! -s "$BATS_TEST_TMPDIR/real-tools.calls" ]
  if grep -q 'PUT\|auth login' "$BATS_TEST_TMPDIR/gh.calls"; then return 1; fi
}

@test "the end-of-install offers are shown and every side effect is stubbed" {
  fake_gh
  printf 'y\n' > "$BATS_TEST_TMPDIR/answer"
  : > "$BATS_TEST_TMPDIR/real-chsh.calls"
  printf '#!/bin/sh\necho real chsh >> "%s/real-chsh.calls"\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bin/chsh"
  chmod +x "$BATS_TEST_TMPDIR/bin/chsh"
  run env -u CI -u CODESPACES HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" SHELL=/bin/zsh \
    ARTEFILES_TTY="$BATS_TEST_TMPDIR/answer" PATH="$BATS_TEST_TMPDIR/bin:$PATH" \
    sh "$SCRIPT" --modules editor --offers --command true
  [ "$status" -eq 0 ]
  [[ "$output" == *"Make fish your default shell?"* ]]
  [[ "$output" == *"Star artefactory/artefiles"* ]]
  [[ "$output" == *"(sandbox) would run: chsh"* ]]
  [[ "$output" == *"(sandbox) would run: gh api -X PUT user/starred/artefactory/artefiles"* ]]
  [ ! -s "$BATS_TEST_TMPDIR/real-chsh.calls" ]
  if grep -q 'PUT' "$BATS_TEST_TMPDIR/gh.calls"; then return 1; fi
}

@test "the fish offer is shown even when the user's login shell is already fish" {
  fake_gh
  printf 'n\n' > "$BATS_TEST_TMPDIR/answer"
  run env -u CI -u CODESPACES HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" SHELL=/usr/bin/fish \
    ARTEFILES_TTY="$BATS_TEST_TMPDIR/answer" PATH="$BATS_TEST_TMPDIR/bin:$PATH" \
    sh "$SCRIPT" --modules editor --offers --command true
  [ "$status" -eq 0 ]
  [[ "$output" == *"Make fish your default shell?"* ]]
}

@test "a selected module's scripts and packages are listed" {
  run_sandbox --modules prek --command 'true'
  [ "$status" -eq 0 ]
  [[ "$output" == *".chezmoiscripts/zzzzz_install-git-hooks.sh"* ]]
}

@test "on macOS terraform's brew package is listed" {
  [ "$(uname -s)" = "Darwin" ] || skip "the brew script is macOS only"
  run_sandbox --modules terraform --command 'true'
  [ "$status" -eq 0 ]
  [[ "$output" == *'brew "hashicorp/tap/terraform"'* ]]
}

@test "on Linux the pinned externals are shown" {
  [ "$(uname -s)" = "Linux" ] || skip "the externals template renders empty outside Linux"
  run_sandbox --modules terraform --command 'true'
  [ "$status" -eq 0 ]
  [[ "$output" == *".local/bin/mergiraf"* ]]
  [[ "$output" == *".local/bin/terraform"* ]]
}

@test "the README says which install features the sandbox shows" {
  grep -qiE 'star offer.*without a token|without a token.*star' "$REPO_ROOT/README.md"
  grep -qiE 'checklist' "$REPO_ROOT/README.md"
}
