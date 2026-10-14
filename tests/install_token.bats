#!/usr/bin/env bats
# chezmoi looks up GitHub releases through the API, which allows 60 requests per
# hour per IP address without a token. install.sh lends gh's token to chezmoi
# unless one is already set. Everything it could change is stubbed.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/calls"
  SEEN="$BATS_TEST_TMPDIR/seen"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  # An existing chezmoi config skips the module checklist, which is not under test.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"

  # chezmoi records the token variables it finds when init runs.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
case "\$1" in
  init) printf 'GITHUB_TOKEN=%s\nCHEZMOI=%s\nACCESS=%s\n' "\${GITHUB_TOKEN:-}" "\${CHEZMOI_GITHUB_ACCESS_TOKEN:-}" "\${GITHUB_ACCESS_TOKEN:-}" > "$SEEN" ;;
  source-path) exit 1 ;;
esac
exit 0
STUB
  # gh is logged in; "auth token" prints GH_FAKE_TOKEN and fails when it is unset.
  cat > "$BIN/gh" << STUB
#!/bin/sh
echo "gh \$*" >> "$CALLS"
if [ "\$1 \$2" = "auth token" ]; then
  [ -n "\${GH_FAKE_TOKEN:-}" ] || exit 1
  echo "\$GH_FAKE_TOKEN"
fi
exit 0
STUB
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# run_install [VAR=VALUE ...] — run install.sh with the stubs, with no token
# variables set and no terminal, so no checklist or prompt appears.
run_install() {
  run env -u CI -u CODESPACES -u GITHUB_TOKEN -u GH_TOKEN -u GITHUB_ACCESS_TOKEN -u CHEZMOI_GITHUB_ACCESS_TOKEN \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" "$@" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
}

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$REPO_ROOT/install.sh"
}

@test "gh's token is lent to chezmoi when none is set" {
  run_install GH_FAKE_TOKEN=gho_lent_token
  [ "$status" -eq 0 ]
  grep -qx 'GITHUB_TOKEN=gho_lent_token' "$SEEN"
}

@test "the lent token is never printed" {
  run_install GH_FAKE_TOKEN=gho_lent_token
  [[ "$output" != *"gho_lent_token"* ]]
}

@test "a token that is already set is kept and gh is not asked for another" {
  run_install GITHUB_TOKEN=mine GH_FAKE_TOKEN=gho_lent_token
  [ "$status" -eq 0 ]
  grep -qx 'GITHUB_TOKEN=mine' "$SEEN"
  if grep -q '^gh auth token' "$CALLS"; then return 1; fi
}

@test "chezmoi's own token variables are respected too" {
  run_install CHEZMOI_GITHUB_ACCESS_TOKEN=theirs GH_FAKE_TOKEN=gho_lent_token
  [ "$status" -eq 0 ]
  grep -qx 'CHEZMOI=theirs' "$SEEN"
  grep -qx 'GITHUB_TOKEN=' "$SEEN"
}

@test "a gh that has no token does not stop the install" {
  run_install
  [ "$status" -eq 0 ]
  grep -qx 'GITHUB_TOKEN=' "$SEEN"
}

@test "dry-run asks gh for no token" {
  run env -u CI -u CODESPACES -u GITHUB_TOKEN HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    GH_FAKE_TOKEN=gho_lent_token sh "$REPO_ROOT/install.sh" --dry-run < /dev/null
  [ "$status" -eq 0 ]
  if grep -q '^gh auth token' "$CALLS"; then return 1; fi
}
