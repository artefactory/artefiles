#!/usr/bin/env bats
# The init prompt shows "<module> | <help>" so users know what a module
# installs, marks alternatives on both sides, and refuses a selection that
# holds both modules of a pair. The README table repeats the same help.

setup() {
  load 'helpers/setup'
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\ncase "$*" in *login*) echo u ;; *) echo u@example.com ;; esac\n' > "$fake_bin/gh"
  chmod +x "$fake_bin/gh"
}

# init_with MODULES_JSON — run a real `chezmoi init` over a stored selection.
init_with() {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  run env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi init --config "$H/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$H"
}

stored_modules() { grep '^modules = ' "$H/.config/chezmoi/chezmoi.toml" | sed 's/^modules = //'; }

@test "every module has a help of at most 110 characters" {
  [ -n "$(prompt_module_names)" ]
  for m in $(prompt_module_names); do
    help=$(prompt_help "$m")
    [ -n "$help" ]
    [ "${#help}" -le 110 ] || { echo "$m help is ${#help} chars" >&2; return 1; }
  done
}

@test "every module offered has a help and the others are not offered" {
  [ "$(prompt_module_names | wc -l)" -eq 12 ]
  [ "$(prompt_choices | wc -l)" -eq "$(prompt_module_names | wc -l)" ]
  [ "$(prompt_module_names | sort | uniq -d | wc -l)" -eq 0 ]
}

@test "alternatives say 'Alternative to X: pick one' on both sides and nothing else does" {
  [ "$(prompt_pairs | wc -l)" -eq 3 ]
  marked=""
  while read -r a b; do
    prompt_help "$a" | grep -qF "Alternative to $b: pick one"
    prompt_help "$b" | grep -qF "Alternative to $a: pick one"
    marked="$marked $a $b"
  done < <(prompt_pairs)
  for m in $(prompt_module_names); do
    case " $marked " in
    *" $m "*) ;;
    *) if prompt_help "$m" | grep -qi 'alternative'; then return 1; fi ;;
    esac
  done
}

@test "README module table repeats the template help and the alternative" {
  while read -r m; do
    row=$(grep -F "| \`$m\` |" "$REPO_ROOT/README.md")
    [ -n "$row" ] || { echo "no README row for $m" >&2; return 1; }
    printf '%s\n' "$row" | grep -qF "| $(prompt_help "$m") |" || { echo "README help drifted for $m" >&2; return 1; }
    partner=$(prompt_pairs | awk -v m="$m" '$1==m{print $2} $2==m{print $1}')
    if [ -n "$partner" ]; then
      printf '%s\n' "$row" | grep -qF "| \`$partner\` |"
    else
      printf '%s\n' "$row" | grep -qE '\| — \|$'
    fi
  done < <(prompt_module_names)
  grep -qF '| Alternative to |' "$REPO_ROOT/README.md"
}

@test "a stored selection of bare names skips the prompt and is kept" {
  init_with '["editor","ghostty","prek","opentofu"]'
  [ "$status" -eq 0 ]
  stored_modules | jq -e '. == ["editor","ghostty","prek","opentofu"]'
}

@test "a selection holding both modules of a pair stops init" {
  [ "$(prompt_pairs | wc -l)" -eq 3 ]
  while read -r a b; do
    init_with "[\"$a\",\"$b\"]"
    [ "$status" -ne 0 ]
    [[ "$output" == *"$a and $b are alternatives: choose one"* ]]
  done < <(prompt_pairs)
}

@test "one module of each pair is accepted" {
  init_with '["ghostty","pre_commit","terraform"]'
  [ "$status" -eq 0 ]
  init_with '["cmux","prek","opentofu"]'
  [ "$status" -eq 0 ]
}

@test "a labeled choice is stored as its bare name" {
  H=$(mk_fake_home)
  rm -f "$H/.config/chezmoi/chezmoi.toml"
  run env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi init --config "$H/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$H" \
    --promptString "Email (default: u@example.com, press enter to accept)=u@example.com" \
    --promptMultichoice "Select optional modules=$(prompt_choices | sed -n 2p)"
  [ "$status" -eq 0 ]
  stored_modules | jq -e --arg m "$(prompt_module_names | sed -n 2p)" '. == [$m]'
}
