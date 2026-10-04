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

# idx NAME — the number the checklist gives to module NAME.
idx() { prompt_module_names | grep -nx "$1" | cut -d: -f1; }

# select_with LINE... — run the checklist feeding one answer per line.
select_with() {
  : > "$ANSWERS"
  for line in "$@"; do printf '%s\n' "$line" >> "$ANSWERS"; done
  run sh -c "ARTEFILES_SELECT_TTY='$ANSWERS' sh '$SCRIPT' 2>'$BATS_TEST_TMPDIR/ui'"
  ui=$(cat "$BATS_TEST_TMPDIR/ui")
}

@test "script passes shellcheck" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not available"
  shellcheck "$SCRIPT"
}

@test "the first screen has a legend and every module unselected with its help" {
  select_with "" y
  [[ "$ui" == *"[x] will be installed"* ]]
  [[ "$ui" == *"[ ] will not be installed"* ]]
  for m in $(prompt_module_names); do
    printf '%s\n' "$ui" | grep -qE "^ *$(idx "$m")\) \[ \] ${m} " || { echo "no unselected line for $m" >&2; return 1; }
    [[ "$ui" == *"$(prompt_help "$m")"* ]] || { echo "help of $m missing" >&2; return 1; }
  done
}

@test "typing a module's number selects it and the list shows [x]" {
  select_with "$(idx editor)" "" y
  [ "$status" -eq 0 ]
  printf '%s\n' "$ui" | grep -qE "^ *$(idx editor)\) \[x\] editor "
  [ "$output" = '["editor"]' ]
}

@test "the result lists the selection in the list's order, not the toggle order" {
  select_with "$(idx atuin)" "$(idx editor)" "" y
  [ "$output" = '["editor","atuin"]' ]
}

@test "toggling a module twice deselects it" {
  select_with "$(idx editor)" "$(idx editor)" "" y
  [ "$output" = '[]' ]
}

@test "n clears the whole selection" {
  select_with "$(idx editor)" "$(idx atuin)" n "" y
  [ "$output" = '[]' ]
}

@test "choosing one module of an alternative pair deselects the other and says so" {
  while read -r a b; do
    select_with "$(idx "$a")" "$(idx "$b")" "" y
    [ "$output" = "[\"$b\"]" ] || { echo "pair $a/$b gave $output" >&2; return 1; }
    [[ "$ui" == *"$a was deselected: it is an alternative to $b"* ]]
  done < <(prompt_pairs)
}

@test "the summary lists what will be installed and n returns to the list" {
  select_with "$(idx editor)" "" n "$(idx atuin)" "" y
  [ "$output" = '["editor","atuin"]' ]
  [[ "$ui" == *"You will install: editor"* ]]
  [[ "$ui" == *"Install these modules? [Y/n]"* ]]
}

@test "an empty selection is confirmed as no optional modules" {
  select_with "" y
  [ "$output" = '[]' ]
  [[ "$ui" == *"no optional modules"* ]]
}

@test "invalid input is reported and ignored" {
  select_with abc 999 "$(idx editor)" "" y
  [ "$status" -eq 0 ]
  [ "$output" = '["editor"]' ]
  [[ "$ui" == *"abc is not a module number"* ]]
  [[ "$ui" == *"999 is not a module number"* ]]
}

@test "running out of input cancels without a result" {
  select_with "$(idx editor)"
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

# submit_idx — the number of the Submit row, right after the last module.
submit_idx() { echo $(($(prompt_module_names | wc -l) + 1)); }

@test "a Submit row closes the list, numbered after the last module" {
  select_with "" y
  last=$(printf '%s\n' "$ui" | grep -E '^ *[0-9]+\)' | sed -n "$(submit_idx)p")
  [[ "$last" == *"$(submit_idx))"*"Submit"* ]]
  [[ "$last" != *"[ ]"* ]] && [[ "$last" != *"[x]"* ]]
}

@test "typing the Submit number goes to the summary, like Enter" {
  select_with "$(idx editor)" "$(submit_idx)" y
  [ "$status" -eq 0 ]
  [ "$output" = '["editor"]' ]
  [[ "$ui" == *"You will install: editor"* ]]
}

@test "the Submit row says the choices are validated once confirmed" {
  select_with "$(idx atuin)" "$(submit_idx)" y
  [[ "$ui" == *"Choices validated: atuin"* ]]
}

@test "declining the summary after Submit returns to the list" {
  select_with "$(idx editor)" "$(submit_idx)" n "$(idx atuin)" "$(submit_idx)" y
  [ "$output" = '["editor","atuin"]' ]
}

@test "the prompt names the Submit number" {
  select_with "" y
  [[ "$ui" == *"$(submit_idx) to submit"* ]]
}

