#!/usr/bin/env bats
# `chezmoi init` reads the user's name and email from `gh api user`. A missing,
# logged-out or refused gh (a CI job token cannot call that endpoint) must not
# stop it: the name falls back to the system user and the email stays empty.

setup() {
  load 'helpers/setup'
  FAKE_BIN="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$FAKE_BIN"
}

# render_with_gh STATUS MESSAGE — render the template with a gh that prints
# MESSAGE on stderr and exits with STATUS for every call.
render_with_gh() {
  printf '#!/bin/sh\necho "%s" >&2\nexit %s\n' "$2" "$1" > "$FAKE_BIN/gh"
  chmod +x "$FAKE_BIN/gh"
  local home
  home=$(mk_fake_home "$BATS_TEST_TMPDIR/home-$RANDOM")
  env PATH="$FAKE_BIN:$PATH" XDG_CONFIG_HOME="$home/.config" HOME="$home" \
    chezmoi execute-template --source "$REPO_ROOT" --destination "$home" --init \
    --promptMultichoice "modules=editor" \
    < "$REPO_ROOT/.chezmoi.toml.tmpl"
}

@test "a gh refused by the API still renders, with the system user as name and no email" {
  rendered=$(render_with_gh 1 "HTTP 403: Resource not accessible by integration")
  printf '%s\n' "$rendered" | grep -qx "name = \"$(id -un)\""
  printf '%s\n' "$rendered" | grep -qx 'email = ""'
}

@test "a gh that is not logged in still renders" {
  rendered=$(render_with_gh 4 "To get started with GitHub CLI, please run:  gh auth login")
  printf '%s\n' "$rendered" | grep -qx "name = \"$(id -un)\""
}

@test "a gh that cannot be run at all still renders" {
  rendered=$(render_with_gh 127 "gh: command not found")
  printf '%s\n' "$rendered" | grep -qx "name = \"$(id -un)\""
  printf '%s\n' "$rendered" | grep -qx 'email = ""'
}

@test "a working gh still wins over the fallback" {
  printf '#!/bin/sh\ncase "$*" in *".login"*) echo octocat;; *".email"*) echo o@example.org;; *) exit 0;; esac\n' > "$FAKE_BIN/gh"
  chmod +x "$FAKE_BIN/gh"
  home=$(mk_fake_home)
  rendered=$(env PATH="$FAKE_BIN:$PATH" XDG_CONFIG_HOME="$home/.config" HOME="$home" \
    chezmoi execute-template --source "$REPO_ROOT" --destination "$home" --init \
    --promptMultichoice "modules=editor" < "$REPO_ROOT/.chezmoi.toml.tmpl")
  printf '%s\n' "$rendered" | grep -qx 'name = "octocat"'
  printf '%s\n' "$rendered" | grep -qx 'email = "o@example.org"'
}

@test "a failing gh on a re-init keeps the name and email already stored" {
  printf '#!/bin/sh\necho "HTTP 403" >&2\nexit 1\n' > "$FAKE_BIN/gh"
  chmod +x "$FAKE_BIN/gh"
  home=$(mk_fake_home)
  seed_chezmoi_config "$home" '{"modules":["editor"],"name":"chicham","email":"stored@example.org"}'
  rendered=$(env PATH="$FAKE_BIN:$PATH" XDG_CONFIG_HOME="$home/.config" HOME="$home" \
    chezmoi execute-template --config "$home/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$home" --init \
    --promptMultichoice "modules=editor" < "$REPO_ROOT/.chezmoi.toml.tmpl")
  printf '%s\n' "$rendered" | grep -qx 'name = "chicham"'
  printf '%s\n' "$rendered" | grep -qx 'email = "stored@example.org"'
}

@test "a working gh updates the stored name" {
  printf '#!/bin/sh\ncase "$*" in *".login"*) echo octocat;; *) exit 0;; esac\n' > "$FAKE_BIN/gh"
  chmod +x "$FAKE_BIN/gh"
  home=$(mk_fake_home)
  seed_chezmoi_config "$home" '{"modules":["editor"],"name":"chicham"}'
  rendered=$(env PATH="$FAKE_BIN:$PATH" XDG_CONFIG_HOME="$home/.config" HOME="$home" \
    chezmoi execute-template --config "$home/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$home" --init \
    --promptMultichoice "modules=editor" < "$REPO_ROOT/.chezmoi.toml.tmpl")
  printf '%s\n' "$rendered" | grep -qx 'name = "octocat"'
}
