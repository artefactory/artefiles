#!/usr/bin/env bats
# install.sh --yes (or ARTEFILES_YES=1) answers every question so the install
# runs unattended: at a terminal that would answer every question with "no" or
# cancel, the install still reaches the end and never reads that terminal. The
# answers given inside chezmoi apply are tested with each script
# (offer_default_shell, offer_star, offer_new_modules, remove_docker_desktop,
# install_restore). Everything the install could change is stubbed.

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  CALLS="$BATS_TEST_TMPDIR/chezmoi.calls"
  ANSWERS="$BATS_TEST_TMPDIR/answers"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  : > "$CALLS"
  # q cancels the checklist and n declines every other question.
  printf 'q\nn\nn\nn\n' > "$ANSWERS"

  # chezmoi records its arguments and the ARTEFILES_YES its scripts would see.
  cat > "$BIN/chezmoi" << STUB
#!/bin/sh
echo "\$* ARTEFILES_YES=\${ARTEFILES_YES:-}" >> "$CALLS"
case "\$1" in
  source-path) exit 1 ;;
esac
exit 0
STUB
  # GH_STATE=ok: gh is logged in; anything else: its github.com token fails.
  cat > "$BIN/gh" << STUB
#!/bin/sh
echo "gh \$*" >> "$CALLS"
case "\$*" in
  "api --hostname github.com rate_limit") [ "\${GH_STATE:-ok}" = ok ] ;;
  "auth login"*) exit 1 ;;
  *) exit 0 ;;
esac
STUB
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

# run_install [VAR=VALUE ...] -- [ARGS...] — install.sh from the checkout, with
# the stubs and a fake terminal that cancels the checklist and answers no.
run_install() {
  local vars=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    vars+=("$1")
    shift
  done
  [ $# -eq 0 ] || shift
  run env -u CI -u CODESPACES -u ARTEFILES_YES -u GH_TOKEN -u GITHUB_TOKEN \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    PATH="$BIN:$PATH" ARTEFILES_SELECT_TTY="$ANSWERS" ARTEFILES_TTY="$ANSWERS" "${vars[@]}" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" "$@" < /dev/null
}

@test "--yes skips the checklist and chezmoi init takes the default modules" {
  run_install -- --yes
  [ "$status" -eq 0 ]
  [[ "$output" != *"Select the optional modules"* ]]
  [[ "$output" != *"Installation cancelled"* ]]
  grep -q '^init .*--promptDefaults' "$CALLS"
  # No config was written by a checklist, so init chose the modules.
  [ ! -f "$H/.config/chezmoi/chezmoi.toml" ]
}

@test "--yes reaches the scripts chezmoi apply runs as ARTEFILES_YES=1" {
  run_install -- --yes
  [ "$status" -eq 0 ]
  grep -q '^apply .* ARTEFILES_YES=1$' "$CALLS"
}

@test "-y is the short form of --yes" {
  run_install -- -y
  [ "$status" -eq 0 ]
  grep -q '^init .*--promptDefaults' "$CALLS"
}

@test "ARTEFILES_YES=1 in the environment acts as --yes" {
  run_install ARTEFILES_YES=1 --
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installation cancelled"* ]]
  grep -q '^init .*--promptDefaults' "$CALLS"
}

@test "without --yes the same terminal cancels the install (control)" {
  run_install --
  [ "$status" -ne 0 ]
  [[ "$output" == *"Installation cancelled"* ]]
  grep -q '^apply' "$CALLS" && return 1
  grep -q 'ARTEFILES_YES=1' "$CALLS" && return 1
  return 0
}

@test "--yes without a GitHub login stops and says how to sign in, never opening the browser" {
  run_install GH_STATE=broken -- --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"--yes does not open the GitHub login"* ]]
  [[ "$output" == *"gh auth login"*"GH_TOKEN"* ]]
  grep -q '^gh auth login' "$CALLS" && return 1
  return 0
}
