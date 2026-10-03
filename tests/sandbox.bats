#!/usr/bin/env bats
# sandbox.sh simulates a new user's install in a throwaway home: it runs
# install.sh there with every side effect stubbed, applies the dotfiles without
# running scripts or externals, previews what chezmoi would run, and opens a
# shell (or runs a command) in it. Cleanup after every kind of exit is tested here.

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
  run_sandbox --modules editor --command 'printf "SANDBOX_HOME=%s\n" "$HOME"'
  [ "$status" -eq 0 ]
  sandbox_home=$(printf '%s\n' "$output" | sed -n 's/^SANDBOX_HOME=//p')
  [ -n "$sandbox_home" ]
  [ "$sandbox_home" != "$REAL_HOME" ]
  [[ "$sandbox_home" == "$BATS_TEST_TMPDIR"/* ]]
}

@test "the sandbox is removed on exit unless --keep is given" {
  run_sandbox --modules editor --command 'printf "SANDBOX_HOME=%s\n" "$HOME"'
  gone=$(printf '%s\n' "$output" | sed -n 's/^SANDBOX_HOME=//p')
  [ ! -e "$gone" ]

  run_sandbox --modules editor --keep --command 'printf "SANDBOX_HOME=%s\n" "$HOME"'
  kept=$(printf '%s\n' "$output" | sed -n 's/^SANDBOX_HOME=//p')
  [ -d "$kept" ]
}

@test "the real home is never written" {
  run_sandbox --modules editor --command 'true'
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$REAL_HOME")" ]
}

@test "the chosen modules decide which configs are applied" {
  run_sandbox --modules atuin --command 'test -e "$HOME/.config/atuin" && ! test -e "$HOME/.config/nvim"'
  [ "$status" -eq 0 ]
  run_sandbox --modules editor --command 'test -e "$HOME/.config/nvim" && ! test -e "$HOME/.config/atuin"'
  [ "$status" -eq 0 ]
}

@test "the sandbox config stores the modules and never prompts" {
  run_sandbox --modules editor,atuin --command 'grep "^modules = " "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"editor"'* ]] && [[ "$output" == *'"atuin"'* ]]
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

# first_choice — what to answer chezmoi's module prompt to select "editor":
# the labeled choice when the template has labels, the bare name otherwise.
first_choice() {
  label=$(sed -nE 's/^# \[\[ \$choices = append \$choices "(editor \| [^"]*)" \]\] #$/\1/p' "$REPO_ROOT/.chezmoi.toml.tmpl")
  printf '%s' "${label:-editor}"
}

@test "without --modules install.sh runs in the sandbox with every side effect stubbed" {
  fake_gh
  # Tools install.sh could call for real: they must never run.
  for tool in brew curl wget chsh sudo; do
    printf '#!/bin/sh\necho "%s $*" >> "%s/real-tools.calls"\n' "$tool" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bin/$tool"
    chmod +x "$BATS_TEST_TMPDIR/bin/$tool"
  done
  : > "$BATS_TEST_TMPDIR/real-tools.calls"
  run env -u CI -u CODESPACES HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" SHELL=/bin/zsh GH_TOKEN=fake \
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" \
    sh "$SCRIPT" --command 'grep "^modules = " "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"' -- \
    --promptString "Email (default: sandboxer@example.com, press enter to accept)=sandboxer@example.com" \
    --promptMultichoice "Select optional modules=$(first_choice)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running 'chezmoi init --apply"* ]]
  [[ "$output" == *'modules = ["editor"]'* ]]
  [ ! -s "$BATS_TEST_TMPDIR/real-tools.calls" ]
  if grep -q 'PUT\|auth login' "$BATS_TEST_TMPDIR/gh.calls"; then return 1; fi
}

@test "a gh that is not logged in gets a simulated login, never a real one" {
  fake_gh
  run env -u CI -u CODESPACES -u GH_TOKEN -u GITHUB_TOKEN HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" SHELL=/bin/zsh \
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" sh "$SCRIPT" --command 'true'
  # A non-interactive run cannot log in, exactly as install.sh refuses in CI.
  [[ "$output" == *"authentication required"* ]]
  if grep -q 'auth login' "$BATS_TEST_TMPDIR/gh.calls"; then return 1; fi
}

@test "the sandbox applies from a copy of the checkout without the externals template" {
  run_sandbox --modules editor --command 'grep "^sourceDir" "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"'
  [ "$status" -eq 0 ]
  src=$(printf '%s\n' "$output" | sed -E 's/^sourceDir = "(.*)"$/\1/')
  [ "$src" != "$REPO_ROOT" ]
  [ ! -e "$src/.chezmoiexternal.toml.tmpl" ]
}

# leftovers — everything a sandbox may leave in TMPDIR.
leftovers() {
  find "$BATS_TEST_TMPDIR" -maxdepth 1 -name 'artefiles-sandbox.*'
}

@test "a normal run leaves nothing behind" {
  run_sandbox --modules editor --command 'true'
  [ "$status" -eq 0 ]
  [ -z "$(leftovers)" ]
}

@test "a failing command still cleans up and its status is kept" {
  run_sandbox --modules editor --command 'exit 3'
  [ "$status" -eq 3 ]
  [ -z "$(leftovers)" ]
}

@test "a failing install cleans up too" {
  fake_gh
  run env -u CI -u CODESPACES -u GH_TOKEN -u GITHUB_TOKEN HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" \
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" sh "$SCRIPT" --command 'true'
  [ "$status" -ne 0 ]
  [ -z "$(leftovers)" ]
}

@test "an interrupted run cleans up" {
  for sig in INT TERM HUP; do
    env HOME="$REAL_HOME" TMPDIR="$BATS_TEST_TMPDIR" PATH="$PATH" \
      sh "$SCRIPT" --modules editor --command 'sleep 30' > /dev/null 2>&1 &
    pid=$!
    # Wait for the sandbox to exist, then interrupt the shell and its child.
    for _ in $(seq 1 100); do [ -n "$(leftovers)" ] && break; sleep 0.1; done
    sleep 1
    pkill -"$sig" -P "$pid" || true
    kill -"$sig" "$pid" 2> /dev/null || true
    wait "$pid" 2> /dev/null || true
    [ -z "$(leftovers)" ] || { echo "left behind after $sig: $(leftovers)" >&2; return 1; }
  done
}

@test "--keep leaves the sandbox and says how to remove it, --clean removes it" {
  run_sandbox --modules editor --keep --command 'true'
  [ "$status" -eq 0 ]
  [ -n "$(leftovers)" ]
  [[ "$output" == *"--clean"* ]]
  run_sandbox --clean
  [ "$status" -eq 0 ]
  [ -z "$(leftovers)" ]
}

@test "--clean removes the leftovers of every kind and nothing else" {
  mkdir -p "$BATS_TEST_TMPDIR/artefiles-sandbox.AbC123" "$BATS_TEST_TMPDIR/artefiles-sandbox.AbC123.stubs" \
    "$BATS_TEST_TMPDIR/artefiles-sandbox.AbC123.src" "$BATS_TEST_TMPDIR/keep-me"
  printf 'x\n' > "$BATS_TEST_TMPDIR/artefiles-sandbox.AbC123/file"
  run_sandbox --clean
  [ "$status" -eq 0 ]
  [ -z "$(leftovers)" ]
  [ -d "$BATS_TEST_TMPDIR/keep-me" ]
  [ -z "$(ls -A "$REAL_HOME")" ]
}

@test "--clean with nothing to remove is not an error" {
  run_sandbox --clean
  [ "$status" -eq 0 ]
}

@test "the scripts chezmoi would run are listed, and none of them runs" {
  run_sandbox --modules python_dev --command 'true'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Scripts chezmoi would run"* ]]
  [[ "$output" == *".chezmoiscripts/zzzzz_install-python-tools.sh"* ]]
}

@test "a module's scripts are only listed when the module is selected" {
  run_sandbox --modules editor --command 'true'
  [ "$status" -eq 0 ]
  [[ "$output" != *".chezmoiscripts/zzzzz_install-python-tools.sh"* ]]
}

@test "on macOS the packages the brew script would install are listed" {
  [ "$(uname -s)" = "Darwin" ] || skip "the brew script is macOS only"
  run_sandbox --modules editor --command 'true'
  [ "$status" -eq 0 ]
  [[ "$output" == *'brew "neovim"'* ]]
}

@test "on Linux the externals that would be downloaded are rendered from the real template" {
  [ "$(uname -s)" = "Linux" ] || skip "the externals template renders empty outside Linux"
  run_sandbox --modules editor --command 'true'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Externals chezmoi would download"* ]]
  [[ "$output" == *".local/bin/starship"* ]]
}

@test "the README says what the sandbox does not exercise and how to clean up" {
  grep -qiE 'curl.*stub|stubbed.*curl|missing-command|not installed' "$REPO_ROOT/README.md"
  grep -qF -- '--clean' "$REPO_ROOT/README.md"
}
