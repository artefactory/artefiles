#!/usr/bin/env bats
# On an apply at a terminal (chezmoi update included), modules a release added
# since the user last chose are offered: the checklist starts from the stored
# modules, marks the new ones, and the answer and the modules shown are saved
# in chezmoi's config. The modules chosen install on the next apply.

setup() {
  load 'helpers/setup'
  SCRIPT=.chezmoiscripts/run_before_offer-new-modules.sh.tmpl
  ANSWERS="$BATS_TEST_TMPDIR/answers"
  H=$(mk_fake_home)
  CONFIG="$H/.config/chezmoi/chezmoi.toml"
}

all_names() { prompt_module_names | jq -R . | jq -sc .; }

# seed DATA_TOML — a chezmoi config holding these [data] lines.
seed() { printf '[data]\n  name = "u"\n  email = "u@example.com"\n  modulesVersion = 2\n%s\n' "$1" > "$CONFIG"; }

# offer KEYS — render the script for the seeded config and run it at a
# terminal that types KEYS.
offer() {
  printf '%s' "$1" > "$ANSWERS"
  chezmoi_render "$H" "$SCRIPT" > "$BATS_TEST_TMPDIR/offer.sh"
  run env HOME="$H" CHEZMOI_CONFIG_FILE="$CONFIG" ARTEFILES_SELECT_TTY="$ANSWERS" \
    sh "$BATS_TEST_TMPDIR/offer.sh"
}

stored() { sed -n "s/^ *$1 = //p" "$CONFIG"; }

UP=$'\033[A'
DOWN=$'\033[B'

@test "a config saved before modulesOffered is offered azure, kubernetes and data, the stored modules checked" {
  seed '  modules = ["editor","atuin"]'
  # Up wraps to Submit; Enter, then Enter confirms.
  offer "$UP"$'\n\n'
  [ "$status" -eq 0 ]
  stored modules | jq -e '. == ["editor","atuin"]'
  [[ "$output" != *"NOT INSTALLED YET"* ]]
  stored modulesOffered | jq -e --argjson all "$(all_names)" '. == $all'
  for m in azure kubernetes data; do grep -qE "\] $m .*\(new\)$" <<< "$output"; done
  [ -z "$(grep '(new)$' <<< "$output" | grep -vE '\] (azure|kubernetes|data) ')" ]
}

@test "a module picked in the offer is saved, and the next apply is said to install it" {
  seed '  modules = ["editor"]
  modulesOffered = '"$(all_names | jq -c 'map(select(. != "azure"))')"
  row=$(prompt_module_names | grep -nx azure | cut -d: -f1)
  # Down to azure, space, then down past the last module to Submit.
  keys=""
  for _ in $(seq 2 "$row"); do keys+="$DOWN"; done
  keys+=" "
  for _ in $(seq "$row" "$(prompt_module_names | wc -l)"); do keys+="$DOWN"; done
  keys+=$'\n\n'
  offer "$keys"
  [ "$status" -eq 0 ]
  stored modules | jq -e '. == ["editor","azure"]'
  [[ "$output" == *"NOT INSTALLED YET: azure"* ]]
  [[ "$output" == *"run:  chezmoi apply"* ]]
}

@test "nothing is asked when every module was already offered" {
  seed '  modules = ["editor"]
  modulesOffered = '"$(all_names)"
  before=$(cat "$CONFIG")
  offer "q"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$CONFIG")" = "$before" ]
}

@test "cancelling keeps the modules and does not ask again" {
  seed '  modules = ["editor"]'
  offer "q"
  [ "$status" -eq 0 ]
  stored modules | jq -e '. == ["editor"]'
  stored modulesOffered | jq -e --argjson all "$(all_names)" '. == $all'
}

@test "without a terminal the config is untouched and the new modules are named" {
  seed '  modules = ["editor"]'
  before=$(cat "$CONFIG")
  chezmoi_render "$H" "$SCRIPT" > "$BATS_TEST_TMPDIR/offer.sh"
  run env HOME="$H" CHEZMOI_CONFIG_FILE="$CONFIG" ARTEFILES_SELECT_TTY=/nonexistent/tty \
    sh "$BATS_TEST_TMPDIR/offer.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$CONFIG")" = "$before" ]
  for m in azure kubernetes data; do [[ "$output" == *"New modules: "*"$m"* ]]; done
}

@test "chezmoi init keeps modulesOffered, and a config from before it gets the earlier module set" {
  fake_bin="$BATS_TEST_TMPDIR/fb"
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\necho u@example.com\n' > "$fake_bin/gh"
  chmod +x "$fake_bin/gh"
  init() {
    env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
      chezmoi init --config "$CONFIG" --source "$REPO_ROOT" --destination "$H" < /dev/null
  }
  seed '  modules = ["editor"]'
  init
  stored modulesOffered | jq -e --argjson all "$(all_names)" '. == ($all - ["azure","kubernetes","data"])'
  seed '  modules = ["editor"]
  modulesOffered = ["editor"]'
  init
  stored modulesOffered | jq -e '. == ["editor"]'
  # --prompt shows every module, so none is offered again on the next apply.
  env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi init --prompt --config "$CONFIG" --source "$REPO_ROOT" --destination "$H" \
    --promptString "Email (default: u@example.com, press enter to accept)=u@example.com" \
    --promptMultichoice "Select optional modules=$(prompt_choices | grep '^editor | ')" < /dev/null
  stored modulesOffered | jq -e --argjson all "$(all_names)" '. == $all'
}

@test "install.sh saves every module as offered with the checklist answer" {
  grep -q 'modulesOffered = ' "$REPO_ROOT/install.sh"
}

@test "nothing renders when every module was shown, so chezmoi verify stays clean" {
  seed '  modules = ["editor"]
  modulesOffered = '"$(all_names)"
  [ -z "$(chezmoi_render "$H" "$SCRIPT" | tr -d '[:space:]')" ]
}
