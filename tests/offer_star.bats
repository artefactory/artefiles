#!/usr/bin/env bats
# At the very end of install.sh the user is offered to star the repository.
# Nothing is starred without an explicit y/yes, and the offer is skipped when
# nobody can answer (CI, Codespaces, no terminal) or the repo is already starred.

setup() {
  load 'helpers/setup'

  SCRIPT="$REPO_ROOT/offer-star.sh"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$STUBS"
  : > "$CALLS"

  # STAR_STATE selects what `gh api user/starred/...` answers: starred (204),
  # missing (404), error (502). PUT_FAIL=1 makes the star request fail.
  cat > "$STUBS/gh" << STUB
#!/bin/sh
echo "gh \$*" >> "$CALLS"
case "\$*" in
  "api user/starred/artefactory/artefiles")
    case "\${STAR_STATE:-missing}" in
      starred) exit 0 ;;
      missing) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
      *) echo "gh: Bad Gateway (HTTP 502)" >&2; exit 1 ;;
    esac ;;
  "api -X PUT user/starred/artefactory/artefiles")
    [ -z "\${PUT_FAIL:-}" ] ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$STUBS/gh"
  ANSWER="$BATS_TEST_TMPDIR/answer"
}

# run_offer ANSWER_TEXT [VAR=VALUE ...] — run with a stubbed PATH, the answer
# fed through the fake terminal and no CI variables.
run_offer() {
  local answer="$1"
  shift
  printf '%s\n' "$answer" > "$ANSWER"
  run env -i PATH="$STUBS:/usr/bin:/bin" HOME="$BATS_TEST_TMPDIR" \
    ARTEFILES_TTY="$ANSWER" "$@" sh "$SCRIPT"
}

puts() { grep -c '^gh api -X PUT' "$CALLS" || true; }

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$SCRIPT"
}

@test "an already starred repository is not offered again" {
  run_offer y STAR_STATE=starred
  [ "$status" -eq 0 ]
  [ "$(puts)" = "0" ]
  [ -z "$output" ]
}

@test "an empty answer stars nothing and says how to star later" {
  run_offer ""
  [ "$status" -eq 0 ]
  [ "$(puts)" = "0" ]
  [[ "$output" == *"artefactory/artefiles"* ]]
}

@test "anything other than y or yes stars nothing" {
  for answer in n no N maybe " " yep "y es"; do
    run_offer "$answer"
    [ "$status" -eq 0 ]
    [ "$(puts)" = "0" ]
  done
}

@test "y, Y and yes star the repository once" {
  for answer in y Y yes; do
    : > "$CALLS"
    run_offer "$answer"
    [ "$status" -eq 0 ]
    [ "$(puts)" = "1" ]
  done
}

@test "CI and Codespaces never star, even with a y" {
  run_offer y CI=true
  [ "$status" -eq 0 ]
  [ "$(puts)" = "0" ]
  run_offer y CODESPACES=true
  [ "$status" -eq 0 ]
  [ "$(puts)" = "0" ]
}

@test "without a terminal nothing is asked and nothing is starred" {
  run_offer y ARTEFILES_TTY=/nonexistent/tty
  [ "$status" -eq 0 ]
  [ "$(puts)" = "0" ]
}

@test "an API error other than 404 is silent and stars nothing" {
  run_offer y STAR_STATE=error
  [ "$status" -eq 0 ]
  [ "$(puts)" = "0" ]
  [ -z "$output" ]
}

@test "nothing happens when gh is not installed" {
  rm "$STUBS/gh"
  run_offer y
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a failing star request never fails the install" {
  run_offer y PUT_FAIL=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"artefactory/artefiles"* ]]
}

@test "install.sh runs the star offer after the shell offer, ignoring its status" {
  shell_line=$(grep -n 'offer-default-shell.sh' "$REPO_ROOT/install.sh" | tail -1 | cut -d: -f1)
  star_line=$(grep -n 'offer-star.sh' "$REPO_ROOT/install.sh" | head -1 | cut -d: -f1)
  [ -n "$shell_line" ] && [ -n "$star_line" ]
  [ "$shell_line" -lt "$star_line" ]
  grep -qE 'offer-star\.sh" \|\| true' "$REPO_ROOT/install.sh"
}

@test "no chezmoi script stars the repository" {
  if grep -rn 'user/starred' "$REPO_ROOT/.chezmoiscripts"; then return 1; fi
}

@test "the offer script is not managed by chezmoi" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  if chezmoi_managed "$H" | grep -F 'offer-star'; then return 1; fi
}
