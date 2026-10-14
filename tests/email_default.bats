#!/usr/bin/env bats
# `chezmoi init` offers a default email: the public GitHub one, else
# firstname.lastname@artefact.com built from a profile name of exactly two plain
# words, else nothing. With no answer given, chezmoi renders that default.

setup() {
  load 'helpers/setup'
  FAKE_BIN="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/gh" << 'STUB'
#!/bin/sh
case "$*" in
  *".login"*) echo "testuser" ;;
  *".email"*) printf '%s\n' "${GH_EMAIL:-}" ;;
  *".name"*) printf '%s\n' "${GH_NAME:-}" ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$FAKE_BIN/gh"
}

# rendered_email EMAIL NAME — the `email = ...` line rendered for a gh profile
# with that public email and display name.
rendered_email() {
  local home
  home=$(mk_fake_home "$BATS_TEST_TMPDIR/home-$RANDOM")
  env GH_EMAIL="$1" GH_NAME="$2" PATH="$FAKE_BIN:$PATH" XDG_CONFIG_HOME="$home/.config" HOME="$home" \
    chezmoi execute-template --source "$REPO_ROOT" --destination "$home" --init \
    --promptMultichoice "modules=editor" \
    < "$REPO_ROOT/.chezmoi.toml.tmpl" | grep '^email = '
}

@test "the public GitHub email is the default when there is one" {
  [ "$(rendered_email "pub@example.org" "Hicham Randrianarivo")" = 'email = "pub@example.org"' ]
}

@test "without a public email, two plain words become firstname.lastname@artefact.com" {
  [ "$(rendered_email "" "Hicham Randrianarivo")" = 'email = "hicham.randrianarivo@artefact.com"' ]
}

@test "a hyphenated first name is kept" {
  [ "$(rendered_email "" "Jean-Pierre Martin")" = 'email = "jean-pierre.martin@artefact.com"' ]
}

@test "a name that is not exactly two plain words gets no guess" {
  for name in "Jean Pierre Martin" "Madonna" "Hélène Dupont" "  " ""; do
    [ "$(rendered_email "" "$name")" = 'email = ""' ] \
      || { echo "name '$name' was guessed: $(rendered_email "" "$name")" >&2; return 1; }
  done
}

@test "the check can fail: a wrong expectation is rejected" {
  ! [ "$(rendered_email "" "Hicham Randrianarivo")" = 'email = "someone.else@artefact.com"' ]
}
