#!/usr/bin/env bats
# At the end of an interactive install, an @artefact.com user whose GitHub
# account is not in the artefactory organisation is told once, last. Nothing is
# shown for a member, another email, a run without a terminal, or a membership
# that cannot be read. Everything install.sh could change is stubbed.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  # An existing config skips the module checklist.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"
  # chezmoi: the email is $EMAIL; there is no source, so no offer runs.
  cat > "$BIN/chezmoi" << 'STUB'
#!/bin/sh
case "$1" in
  execute-template) printf '%s' "$EMAIL" ;;
  source-path) exit 1 ;;
esac
exit 0
STUB
  # gh answers the membership lookup as $MEMBERSHIP says.
  cat > "$BIN/gh" << 'STUB'
#!/bin/sh
case "$*" in
  "api -i user/memberships/orgs/artefactory")
    case "$MEMBERSHIP" in
      active) printf 'HTTP/2.0 200 OK\n\n{"state":"active","role":"member"}\n' ;;
      pending) printf 'HTTP/2.0 200 OK\n\n{"state":"pending","role":"member"}\n' ;;
      missing) printf 'HTTP/2.0 404 Not Found\n\n{"message":"Not Found"}\n'; exit 1 ;;
      forbidden) printf 'HTTP/2.0 403 Forbidden\n\n{"message":"Forbidden"}\n'; exit 1 ;;
    esac ;;
esac
exit 0
STUB
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sudo"
  chmod +x "$BIN"/*
}

# install EMAIL MEMBERSHIP [VAR=VALUE ...] — an interactive install.
install() {
  local email="$1" membership="$2"
  shift 2
  run env -u CI -u CODESPACES HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    EMAIL="$email" MEMBERSHIP="$membership" ARTEFILES_SELECT_TTY=1 ARTEFILES_SUDO_REFRESH=1 "$@" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
}

NOT_MEMBER="Warning: your GitHub account is not yet in the artefactory organisation."
PENDING="Warning: an invitation to the artefactory organisation is waiting"

@test "a member sees nothing" {
  install me@artefact.com active
  [ "$status" -eq 0 ]
  [[ "$output" != *"artefactory organisation"* ]]
}

@test "a pending invitation is pointed out, once, as the last message" {
  install me@artefact.com pending
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c "$PENDING")" -eq 1 ]
  [[ "$(printf '%s\n' "$output" | tail -n 1)" == "$PENDING"*"https://github.com/orgs/artefactory/invitation" ]]
}

@test "a non-member is warned, once, as the last message" {
  install me@artefact.com missing
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c "$NOT_MEMBER")" -eq 1 ]
  [[ "$(printf '%s\n' "$output" | tail -n 1)" == "$NOT_MEMBER"* ]]
}

@test "a membership that cannot be read shows nothing" {
  install me@artefact.com forbidden
  [ "$status" -eq 0 ]
  [[ "$output" != *"artefactory organisation"* ]]
}

@test "another email shows nothing" {
  install me@example.com missing
  [ "$status" -eq 0 ]
  [[ "$output" != *"artefactory organisation"* ]]
}

@test "a run without a terminal shows nothing" {
  run env -u CI -u CODESPACES -u ARTEFILES_SELECT_TTY HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:$PATH" \
    EMAIL=me@artefact.com MEMBERSHIP=missing sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *"artefactory organisation"* ]]
}
