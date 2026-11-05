#!/usr/bin/env bats
# install.sh logs in to GitHub only when the token gh uses for github.com does
# not work. `gh auth status` fails when any stored account on any host has a
# problem, so a second, stale account must not force a new login. Everything
# is stubbed.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  # An existing chezmoi config skips the module checklist, which is not under test.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"

  printf '#!/bin/sh\n[ "$1" = source-path ] && exit 1\nexit 0\n' > "$BIN/chezmoi"
  # A stale second account makes `gh auth status` fail in every state.
  # GH_STATE says whether the token gh uses for github.com works:
  #   active_ok      the github.com probe succeeds
  #   active_broken  the github.com probe fails with a 401
  cat > "$BIN/gh" << STUB
#!/bin/sh
echo "gh \$*" >> "$CALLS"
case "\$*" in
  "auth status"*) exit 1 ;;
  "api --hostname github.com rate_limit")
    [ "\$GH_STATE" = active_ok ] && exit 0
    echo "HTTP 401: Bad credentials (https://api.github.com/rate_limit)" >&2
    exit 1 ;;
esac
exit 0
STUB
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# run_install GH_STATE [VAR=VALUE ...] — run install.sh with the stubs, no token
# variables and no terminal, so a needed login fails instead of opening a browser.
run_install() {
  state="$1"
  shift
  run env -u CI -u CODESPACES -u GITHUB_TOKEN -u GH_TOKEN -u GITHUB_ACCESS_TOKEN -u CHEZMOI_GITHUB_ACCESS_TOKEN \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" GH_STATE="$state" "$@" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
}

@test "a stale second account does not force a new GitHub login" {
  run_install active_ok
  [ "$status" -eq 0 ]
  [[ "$output" == *"GitHub CLI already authenticated"* ]]
  ! grep -q '^gh auth login' "$CALLS"
}

@test "a broken github.com token still asks for a login" {
  run_install active_broken
  [ "$status" -ne 0 ]
  [[ "$output" == *"GitHub CLI authentication required"* ]]
}

@test "a broken token in GH_TOKEN is reported with gh's error" {
  run_install active_broken GH_TOKEN=gho_broken
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid GitHub token provided in environment variables"* ]]
  [[ "$output" == *"HTTP 401: Bad credentials"* ]]
}

@test "the login check asks GitHub about the github.com token only" {
  run_install active_ok
  grep -qx 'gh api --hostname github.com rate_limit' "$CALLS"
}

@test "every gh auth login targets github.com, the host the check reads" {
  # A login to another host (GH_HOST, or gh's host prompt) would leave the
  # github.com check failing and ask again on the next run.
  # Prints the number of login commands, then how many lack --hostname github.com.
  run awk '/gh auth login/ { in_login = 1; cmd = "" }
    in_login { cmd = cmd $0 }
    in_login && /--web/ { n++; if (cmd !~ /--hostname github\.com/) bad++; in_login = 0 }
    END { print n + 0, bad + 0 }' "$REPO_ROOT/install.sh"
  [ "$output" = "2 0" ]
}
