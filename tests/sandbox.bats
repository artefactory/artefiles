#!/usr/bin/env bats
# sandbox.sh lets you see what a new user sees: it runs the first-run prompts
# in a throwaway home, applies the dotfiles there without running scripts or
# externals, shows the end-of-install offers with their side effects stubbed,
# and opens a shell (or runs a command) in it.

setup() {
  load 'helpers/setup'
  SCRIPT="$REPO_ROOT/sandbox.sh"
  # A stand-in for the user's real home: it must stay untouched.
  REAL_HOME="$BATS_TEST_TMPDIR/real-home"
  mkdir -p "$REAL_HOME"
}

# run_sandbox ARGS... — run sandbox.sh with a fake real home and a clean env.
run_sandbox() {
  run env -u CI -u CODESPACES HOME="$REAL_HOME" XDG_CONFIG_HOME="$REAL_HOME/.config" TMPDIR="$BATS_TEST_TMPDIR" \
    PATH="$PATH" sh "$SCRIPT" "$@"
}

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$SCRIPT"
}

@test "the command runs with HOME pointing at a sandbox, not the real home" {
  run_sandbox --modules editor --command 'printf "%s" "$HOME"'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$output" != "$REAL_HOME" ]
  [[ "$output" == "$BATS_TEST_TMPDIR"/* ]]
}

@test "the sandbox is removed on exit unless --keep is given" {
  run_sandbox --modules editor --command 'printf "%s" "$HOME"'
  [ ! -e "$output" ]

  run_sandbox --modules editor --keep --command 'printf "%s\n" "$HOME"'
  kept=$(printf '%s\n' "$output" | head -1)
  [ -d "$kept" ]
}

@test "the real home is never written" {
  run_sandbox --modules editor --command 'true'
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$REAL_HOME")" ]
}

@test "the chosen modules decide which configs are applied" {
  run_sandbox --modules ghostty --command 'test -e "$HOME/.config/ghostty/config" && ! test -e "$HOME/.config/nvim"'
  [ "$status" -eq 0 ]
  run_sandbox --modules editor --command 'test -e "$HOME/.config/nvim" && ! test -e "$HOME/.config/ghostty"'
  [ "$status" -eq 0 ]
}

@test "the sandbox config stores the modules and never prompts" {
  run_sandbox --modules editor,atuin --command 'grep "^modules = " "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"editor"'* ]] && [[ "$output" == *'"atuin"'* ]]
}

@test "alternative modules are refused" {
  run_sandbox --modules ghostty,cmux --command 'true'
  [ "$status" -ne 0 ]
  [[ "$output" == *"alternatives"* ]]
}

@test "scripts and externals are never run" {
  grep -qF -- '--exclude=scripts,externals' "$SCRIPT"
}

@test "the script is not managed by chezmoi" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  if chezmoi_managed "$H" | grep -F 'sandbox.sh'; then return 1; fi
}

@test "the README documents the sandbox" {
  grep -qF 'sandbox.sh' "$REPO_ROOT/README.md"
  grep -qF 'docker-test.sh' "$REPO_ROOT/README.md"
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

@test "without --modules install.sh runs interactively in the sandbox with every side effect stubbed" {
  fake_gh
  # Tools install.sh could call for real: they must never run.
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
  [[ "$output" == *"Running 'chezmoi init --apply"* ]]
  [[ "$output" == *'modules = ["ghostty"]'* ]]
  [[ "$output" == *"Make fish your default shell?"* ]]
  [[ "$output" == *"(sandbox) would run: chsh"* ]]
  [ ! -s "$BATS_TEST_TMPDIR/real-tools.calls" ]
  if grep -q 'PUT\|auth login' "$BATS_TEST_TMPDIR/gh.calls"; then return 1; fi
}

@test "a gh that is not logged in gets a simulated login, never a real one" {
  fake_gh
  printf 'n\n' > "$BATS_TEST_TMPDIR/answer"
  run env -u CI -u CODESPACES -u GH_TOKEN -u GITHUB_TOKEN HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" SHELL=/bin/zsh \
    ARTEFILES_TTY="$BATS_TEST_TMPDIR/answer" PATH="$BATS_TEST_TMPDIR/bin:$PATH" \
    sh "$SCRIPT" --command 'true' -- \
    --promptString "Email (default: sandboxer@example.com, press enter to accept)=sandboxer@example.com" \
    --promptMultichoice "Select optional modules=$(prompt_choices | sed -n 1p)"
  # A non-interactive run cannot log in, exactly as install.sh refuses in CI.
  [[ "$output" == *"authentication required"* ]]
  if grep -q 'auth login' "$BATS_TEST_TMPDIR/gh.calls"; then return 1; fi
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

@test "the README says the sandbox shows the first-run experience" {
  grep -qiE 'new user|first-run|first run' "$REPO_ROOT/README.md"
}

@test "the sandbox applies from a copy of the checkout without the externals template" {
  run_sandbox --modules editor --command 'grep "^sourceDir" "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"'
  [ "$status" -eq 0 ]
  src=$(printf '%s\n' "$output" | sed -E 's/^sourceDir = "(.*)"$/\1/')
  [ "$src" != "$REPO_ROOT" ]
  [ ! -e "$src/.chezmoiexternal.toml.tmpl" ]
}

