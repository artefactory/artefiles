#!/usr/bin/env bats
# dotfiles_doctor returns 1 on a problem and 0 otherwise, checks only the tools
# of the selected modules, and reads chezmoi doctor's lines instead of its exit
# code, which stays 0 on a check that could not run.

setup() {
  load 'helpers/setup'
  command -v fish > /dev/null || skip "fish is not installed"
  H=$(mk_fake_home)
  BIN="$BATS_TEST_TMPDIR/bin"
  SRC="$BATS_TEST_TMPDIR/src"
  mkdir -p "$BIN" "$SRC"
  git -C "$SRC" init -q -b main
  git -C "$SRC" -c core.hooksPath=/dev/null -c user.email=t@e -c user.name=t commit -q --allow-empty -m init
  DOCTOR_OUT="$BATS_TEST_TMPDIR/doctor.out"
  printf 'ok        version       v2.73.2\n' > "$DOCTOR_OUT"
  # The chezmoi stub answers the subcommands dotfiles_doctor calls.
  cat > "$BIN/chezmoi" << EOF
#!/bin/sh
case "\$1" in
  --version) echo "chezmoi version v2.73.2" ;;
  source-path) echo "$SRC" ;;
  managed) [ -n "\$MANAGED_FAIL" ] && { echo "chezmoi: managed broke" >&2; exit 1; }
    printf '%s\n' .gitconfig .config/starship.toml ;;
  status) [ -n "\$STATUS_FAIL" ] && { echo "chezmoi: 403 API rate limit exceeded" >&2; exit 1; }
    : ;;
  doctor) cat "$DOCTOR_OUT" ;;
esac
EOF
  chmod +x "$BIN/chezmoi"
  touch "$H/.gitconfig"
  mkdir -p "$H/.config" && touch "$H/.config/starship.toml"
}

# tools NAME... — a stub for each tool that prints a version.
tools() {
  for t in "$@"; do
    printf '#!/bin/sh\necho "%s 1.0"\n' "$t" > "$BIN/$t"
    chmod +x "$BIN/$t"
  done
}

# run_doctor MODULES_JSON — render dotfiles_doctor for the modules and run it.
run_doctor() {
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  chezmoi_render "$H" dot_config/fish/functions/dotfiles_doctor.fish.tmpl > "$BATS_TEST_TMPDIR/dd.fish"
  run env -i HOME="$H" PATH="$BIN:/usr/bin:/bin" STATUS_FAIL="${STATUS_FAIL:-}" MANAGED_FAIL="${MANAGED_FAIL:-}" "$(command -v fish)" --no-config \
    -c "source $BATS_TEST_TMPDIR/dd.fish; dotfiles_doctor"
}

CORE=(fish starship git gh fnm mergiraf uv hostname)

@test "with every core tool and no module, the doctor finds no problem" {
  tools "${CORE[@]}"
  run_doctor '[]'
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 problem(s)"* ]]
  [[ "$output" != *"## Editor"* ]]
}

@test "a missing tool of a selected module is a problem" {
  tools "${CORE[@]}"
  run_doctor '["editor"]'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ nvim: not installed"* ]]
}

@test "a managed config missing on disk is a problem; an unmanaged one is not checked" {
  tools "${CORE[@]}"
  rm "$H/.config/starship.toml"
  run_doctor '[]'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ config: .config/starship.toml missing"* ]]
  [[ "$output" != *".config/fish/config.fish"* ]]
}

@test "a chezmoi doctor check that failed is a problem, though chezmoi doctor exits 0" {
  tools "${CORE[@]}"
  printf 'ok        version       v2.73.2\nfailed    config-file   cannot read\n' > "$DOCTOR_OUT"
  run_doctor '[]'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ chezmoi doctor: failed config-file cannot read"* ]]
}

@test "a chezmoi doctor warning and a dirty source are warnings, not problems" {
  tools "${CORE[@]}"
  printf 'warning   working-tree  dirty\n' > "$DOCTOR_OUT"
  touch "$SRC/untracked"
  run_doctor '[]'
  [ "$status" -eq 0 ]
  [[ "$output" == *"! chezmoi doctor: warning working-tree dirty"* ]]
  [[ "$output" == *"! source: uncommitted changes"* ]]
  [[ "$output" == *"0 problem(s), 2 warning(s)"* ]]
}

@test "a conda on PATH is a problem" {
  tools "${CORE[@]}" conda
  run_doctor '[]'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ conda: forbidden, found in PATH"* ]]
}

@test "a failing chezmoi status is a problem, not a clean list of files" {
  tools "${CORE[@]}"
  STATUS_FAIL=1 run_doctor '[]'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ files: chezmoi status failed: chezmoi: 403 API rate limit exceeded"* ]]
  [[ "$output" != *"every managed file matches"* ]]
}

@test "a failing chezmoi managed is a problem, not skipped config checks" {
  tools "${CORE[@]}"
  MANAGED_FAIL=1 run_doctor '[]'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ chezmoi managed failed, configs not checked: chezmoi: managed broke"* ]]
}
