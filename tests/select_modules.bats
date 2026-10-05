#!/usr/bin/env bats
# select-modules.sh is the module checklist install.sh runs before chezmoi init:
# [x] will be installed, [ ] will not, alternatives replace each other and a
# summary asks for confirmation. The UI goes to stderr, the result (a JSON
# array of bare module names) to stdout.

setup() {
  load 'helpers/setup'
  SCRIPT="$REPO_ROOT/select-modules.sh"
  ANSWERS="$BATS_TEST_TMPDIR/answers"
}

# idx NAME — the row the checklist gives to module NAME (1-based).
idx() { prompt_module_names | grep -nx "$1" | cut -d: -f1; }

# submit_idx — the Submit row, right after the last module.
submit_idx() { echo $(($(prompt_module_names | wc -l) + 1)); }

# Keystrokes are built as a byte string: KEYS accumulates, POS tracks the pointer.
DOWN=$'\033[B'
UP=$'\033[A'
# reset_keys starts from an empty selection (n clears the defaults); keep_defaults starts from the template's.
reset_keys() { KEYS="n"; POS=1; }
keep_defaults() { KEYS=""; POS=1; }
# to ROW — move the pointer to ROW with arrow keys.
to() {
  while [ "$POS" -lt "$1" ]; do KEYS+="$DOWN"; POS=$((POS + 1)); done
  while [ "$POS" -gt "$1" ]; do KEYS+="$UP"; POS=$((POS - 1)); done
}
# pick NAME — move to module NAME and toggle it with space.
pick() { to "$(idx "$1")"; KEYS+=" "; }
# submit — move to the Submit row and press Enter.
submit() { to "$(submit_idx)"; KEYS+=$'\n'; }
# raw BYTES — append bytes as typed.
raw() { KEYS+="$1"; }

# run_keys — run the checklist feeding KEYS.
run_keys() {
  printf '%s' "$KEYS" > "$ANSWERS"
  run sh -c "ARTEFILES_SELECT_TTY='$ANSWERS' sh '$SCRIPT' 2>'$BATS_TEST_TMPDIR/ui'"
  ui=$(cat "$BATS_TEST_TMPDIR/ui")
}

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$SCRIPT"
}

@test "the first screen has a legend, the pointer on the first row and every module with its help" {
  keep_defaults; submit; raw $'y\n'; run_keys
  [[ "$ui" == *"[x] will be installed"* ]]
  [[ "$ui" == *"[ ] will not be installed"* ]]
  printf '%s\n' "$ui" | grep -qE "^> \[.\] $(prompt_module_names | head -1) "
  for m in $(prompt_module_names); do
    printf '%s\n' "$ui" | grep -qE "^[> ] \[.\] ${m} " || { echo "no line for $m" >&2; return 1; }
    [[ "$ui" == *"$(prompt_help "$m")"* ]] || { echo "help of $m missing" >&2; return 1; }
  done
}

@test "space on a row selects it and the list shows [x]" {
  reset_keys; pick editor; submit; raw $'y\n'; run_keys
  [ "$status" -eq 0 ]
  printf '%s\n' "$ui" | grep -qE "^[> ] \[x\] editor "
  [ "$output" = '["editor"]' ]
}

@test "the down arrow moves the pointer" {
  keep_defaults; raw "$DOWN"; raw "$DOWN"; raw q; run_keys
  third=$(prompt_module_names | sed -n 3p)
  printf '%s\n' "$ui" | grep -qE "^> \[.\] ${third} "
}

@test "k and j move like the arrows" {
  reset_keys; raw j; raw j; raw k; POS=2; raw " "; submit; raw $'y\n'; run_keys
  [ "$output" = "[\"$(prompt_module_names | sed -n 2p)\"]" ]
}

@test "the up arrow wraps from the first row to Submit" {
  reset_keys; raw "$UP"; raw q; run_keys
  printf '%s\n' "$ui" | grep -qE "^> \[ Submit \]"
}

@test "the down arrow wraps from Submit to the first row" {
  reset_keys; to "$(submit_idx)"; raw "$DOWN"; raw q; run_keys
  printf '%s\n' "$ui" | tail -n 30 | grep -qE "^> \[.\] $(prompt_module_names | head -1) "
}

@test "Enter on a module row toggles it" {
  reset_keys; raw $'\n'; submit; raw $'y\n'; run_keys
  [ "$output" = "[\"$(prompt_module_names | head -1)\"]" ]
}

@test "the result lists the selection in the list's order, not the toggle order" {
  reset_keys; pick atuin; pick editor; submit; raw $'y\n'; run_keys
  [ "$output" = '["editor","atuin"]' ]
}

@test "toggling a module twice deselects it" {
  reset_keys; pick editor; raw ' '; submit; raw $'y\n'; run_keys
  [ "$output" = '[]' ]
}

@test "n clears the whole selection" {
  reset_keys; pick editor; pick atuin; raw n; submit; raw $'y\n'; run_keys
  [ "$output" = '[]' ]
}

@test "choosing one module of an alternative pair deselects the other and says so" {
  while read -r a b; do
    reset_keys; pick "$a"; pick "$b"; submit; raw $'y\n'; run_keys
    [ "$output" = "[\"$b\"]" ] || { echo "pair $a/$b gave $output" >&2; return 1; }
    [[ "$ui" == *"$a was deselected: it is an alternative to $b"* ]]
  done < <(prompt_pairs)
}

@test "the summary lists what will be installed and n returns to the list" {
  reset_keys; pick editor; submit; raw $'n\n'; POS=1; pick atuin; submit; raw $'y\n'; run_keys
  [ "$output" = '["editor","atuin"]' ]
  [[ "$ui" == *"You will install: editor"* ]]
  [[ "$ui" == *"Install these modules? [Y/n]"* ]]
}

@test "an empty selection is confirmed as no optional modules" {
  reset_keys; submit; raw $'y\n'; run_keys
  [ "$output" = '[]' ]
  [[ "$ui" == *"no optional modules"* ]]
}

@test "unknown keys are ignored" {
  reset_keys; raw z; raw $'\033[C'; pick editor; submit; raw $'y\n'; run_keys
  [ "$status" -eq 0 ]
  [ "$output" = '["editor"]' ]
}

@test "q cancels without a result" {
  reset_keys; pick editor; raw q; run_keys
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$ui" == *"cancelled"* ]]
}

@test "running out of input cancels without a result" {
  reset_keys; pick editor; run_keys
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [[ "$ui" == *"cancelled"* ]]
}

@test "without a readable terminal nothing is asked and nothing is printed" {
  run sh -c "ARTEFILES_SELECT_TTY=/nonexistent/tty sh '$SCRIPT' 2>/dev/null"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "module names and help texts live only in the template" {
  for m in $(prompt_module_names); do
    if grep -nwF "$m" "$SCRIPT"; then echo "$m is hard-coded in select-modules.sh" >&2; return 1; fi
  done
}

@test "the checklist script is not managed by chezmoi" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  if chezmoi_managed "$H" | grep -F 'select-modules'; then return 1; fi
}

@test "the README explains the checklist" {
  grep -qF '[x]' "$REPO_ROOT/README.md"
  grep -qi 'checklist' "$REPO_ROOT/README.md"
}

@test "a Submit row closes the list and has no checkbox" {
  reset_keys; submit; raw $'y\n'; run_keys
  last=$(printf '%s\n' "$ui" | grep -E '^[> ] \[ Submit \]' | head -1)
  [[ "$last" == *"Submit"* ]]
  [[ "$last" != *"[x]"* ]]
}

@test "the Submit row says the choices are validated once confirmed" {
  reset_keys; pick atuin; submit; raw $'y\n'; run_keys
  [[ "$ui" == *"Choices validated: atuin"* ]]
}

@test "the footer names the keys" {
  reset_keys; raw q; run_keys
  [[ "$ui" == *"up/down"* ]]
  [[ "$ui" == *"space toggles"* ]]
}

# defaults — the modules the template lists as preselected, one per line.
defaults() {
  # shellcheck disable=SC2016 # the pattern matches a literal `$defaults`
  sed -nE 's/^# \[\[ \$defaults := list (.*) \]\] #$/\1/p' "$REPO_ROOT/.chezmoi.toml.tmpl" | tr -d '"' | tr ' ' '\n'
}

@test "the template lists the default modules and each one is offered" {
  [ "$(defaults | wc -l | tr -d ' ')" -gt 0 ]
  for m in $(defaults); do
    prompt_module_names | grep -qx "$m" || { echo "$m is a default but not offered" >&2; return 1; }
  done
}

@test "the first screen shows the default modules as [x] and the others as [ ]" {
  keep_defaults; raw q; run_keys
  first=$(printf '%s\n' "$ui" | awk '/Select the optional modules/{n++} n==1')
  for m in $(prompt_module_names); do
    if defaults | grep -qx "$m"; then want='\[x\]'; else want='\[ \]'; fi
    printf '%s\n' "$first" | grep -qE "^[> ] ${want} ${m} " || { echo "$m is not $want" >&2; return 1; }
  done
}

@test "confirming straight away installs exactly the default modules" {
  keep_defaults; submit; raw $'y\n'; run_keys
  expected=$(for m in $(prompt_module_names); do if defaults | grep -qx "$m"; then printf '"%s",' "$m"; fi; done)
  [ "$output" = "[${expected%,}]" ]
}

@test "a default can be untoggled" {
  keep_defaults; pick editor; submit; raw $'y\n'; run_keys
  [[ "$output" != *'"editor"'* ]]
  [[ "$output" == *'"atuin"'* ]]
}
