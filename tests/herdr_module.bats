#!/usr/bin/env bats
# The herdr module installs herdr, a terminal multiplexer for coding agents
# (herdrdev/herdr): the Homebrew formula on macOS, the release binary on Linux.
# herdr is started by typing `herdr`, like tmux: Ghostty opens the login shell.
# ghostty and herdr are selected by default. Zellij and the cmux module are
# gone; a stored cmux reads as ghostty.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

PKG=.chezmoidata/packages.yaml
DARWIN_TMPL=.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl
GHOSTTY=dot_config/ghostty/config.tmpl
DOCTOR=dot_config/fish/functions/dotfiles_doctor.fish.tmpl
REF=.claude/skills/artefiles/references/herdr.md

# A negative check (`grep -c X` is 0) passes on an empty render, so each render
# fails on a non-zero exit and on a missing sentinel line that every render of
# its file holds. Callers capture it (out=$(render ...)) so a failure fails the
# test instead of vanishing in a pipe.

# sentinel FILE — a line every render of FILE contains.
sentinel() {
  case "$1" in
  "$DARWIN_TMPL") echo 'brew bundle' ;;
  "$DOCTOR") echo 'function dotfiles_doctor' ;;
  "$GHOSTTY") echo 'theme = Catppuccin Mocha' ;;
  *) echo "no sentinel for $1" >&2; return 1 ;;
  esac
}

# render MODULES_JSON FILE — FILE rendered for a home with these modules.
render() {
  local out want
  want=$(sentinel "$2") || return 1
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  out=$(chezmoi_render "$H" "$2") || { echo "render of $2 failed" >&2; return 1; }
  grep -qF "$want" <<< "$out" || { echo "render of $2 lacks: $want" >&2; return 1; }
  printf '%s\n' "$out"
}

# render_linux MODULES_JSON — the externals file rendered for Linux; the
# template is guarded by `eq .chezmoi.os "linux"`, so the guard is forced.
render_linux() {
  local out
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  out=$(XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < <(sed 's/eq \.chezmoi\.os "linux"/true/' "$REPO_ROOT/.chezmoiexternal.toml.tmpl")) \
    || { echo "render of the externals failed" >&2; return 1; }
  # The same sentinel as tests/externals.bats: the Linux branch rendered.
  grep -qF '[".local/bin/starship"]' <<< "$out" || { echo "externals lack starship" >&2; return 1; }
  printf '%s\n' "$out"
}

# defaults — the modules the template lists as preselected, one per line.
defaults() {
  # shellcheck disable=SC2016 # the pattern matches a literal `$defaults`
  sed -nE 's/^# \[\[ \$defaults := list (.*) \]\] #$/\1/p' "$REPO_ROOT/.chezmoi.toml.tmpl" | tr -d '"' | tr ' ' '\n'
}

@test "the init prompt offers herdr right after ghostty, and no cmux" {
  [ "$(prompt_module_names | grep -A1 -x ghostty | tail -n 1)" = herdr ]
  [ "$(prompt_module_names | grep -cx cmux)" -eq 0 ]
  [[ "$(prompt_help herdr)" == *"coding agents"* ]]
  # The ghostty help names neither Zellij nor cmux, and pairs with nothing.
  if prompt_help ghostty | grep -qiE 'zellij|cmux|alternative'; then return 1; fi
  [ "$(prompt_pairs | grep -c ghostty)" -eq 0 ]
}

@test "ghostty and herdr are selected by default" {
  defaults | grep -qx ghostty
  defaults | grep -qx herdr
}

@test "herdr installs the herdr formula on macOS, only when selected" {
  [ "$(yq -o=json -I=0 '.packages.darwin.modules.herdr.brews' "$REPO_ROOT/$PKG")" = '["herdr"]' ]
  [ "$(yq -r '.packages.darwin.modules.herdr.casks | length' "$REPO_ROOT/$PKG")" -eq 0 ]
  out=$(render '["herdr"]' "$DARWIN_TMPL")
  grep -qxF 'brew "herdr"' <<< "$out"
  out=$(render '["ghostty"]' "$DARWIN_TMPL")
  [ "$(grep -c 'herdr' <<< "$out")" -eq 0 ]
}

@test "ghostty installs only the Ghostty cask on macOS, and no module installs zellij or cmux" {
  [ "$(yq -o=json -I=0 '.packages.darwin.modules.ghostty.casks' "$REPO_ROOT/$PKG")" = '["ghostty"]' ]
  [ "$(yq -r '.packages.darwin.modules.ghostty.brews | length' "$REPO_ROOT/$PKG")" -eq 0 ]
  [ "$(yq -r '.packages.darwin.modules | has("cmux")' "$REPO_ROOT/$PKG")" = false ]
  out=$(render "$(all_modules_json)" "$DARWIN_TMPL")
  if grep -qiE 'zellij|cmux' <<< "$out"; then return 1; fi
}

@test "herdr installs the latest release binary of herdrdev/herdr on Linux, only when selected" {
  out=$(render_linux '["herdr"]')
  block=$(grep -A4 -F '[".local/bin/herdr"]' <<< "$out")
  grep -qE '^  url = "https://github\.com/herdrdev/herdr/releases/download/[^"]+/herdr-linux-(x86_64|aarch64)"$' <<< "$block"
  grep -qxF '  executable = true' <<< "$block"
  out=$(render_linux '["ghostty"]')
  [ "$(grep -c 'herdr' <<< "$out")" -eq 0 ]
  out=$(render_linux "$(all_modules_json)")
  if grep -qi 'zellij' <<< "$out"; then return 1; fi
}

@test "Ghostty opens the login shell, even with herdr selected, and never names Zellij" {
  out=$(render '["ghostty","herdr"]' "$GHOSTTY")
  grep -qxF 'theme = Catppuccin Mocha' <<< "$out"
  [ "$(grep -c '^command' <<< "$out")" -eq 0 ]
  if grep -qi zellij "$REPO_ROOT/$GHOSTTY"; then return 1; fi
}

@test "the Ghostty config is managed for ghostty and a stored cmux, not for herdr alone" {
  for m in ghostty cmux; do
    H=$(mk_fake_home "$BATS_TEST_TMPDIR/h-$m")
    seed_chezmoi_config "$H" "{\"modules\":[\"$m\"]}"
    chezmoi_managed "$H" | grep -qx '.config/ghostty/config'
  done
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/h-herdr")
  seed_chezmoi_config "$H" '{"modules":["herdr"]}'
  if chezmoi_managed "$H" | grep -q '^\.config/ghostty'; then return 1; fi
}

@test "the doctor checks herdr with its module" {
  out=$(render '["ghostty"]' "$DOCTOR")
  [ "$(grep -c 'herdr' <<< "$out")" -eq 0 ]
  out=$(render '["herdr"]' "$DOCTOR")
  grep -qxF '    __check_tool_with_configs herdr "" $managed_files' <<< "$out"
}

@test "herdr has its README and cheatsheet rows and a reference; cmux has none" {
  grep -qF "| \`herdr\` | $(prompt_help herdr) | — |" "$REPO_ROOT/README.md"
  grep -qF "| \`herdr\` | $(prompt_help herdr) | [herdr]($REF) |" "$REPO_ROOT/CHEATSHEET.md"
  grep -qF 'herdrdev/herdr' "$REPO_ROOT/$REF"
  grep -qF "| \`ghostty\` | $(prompt_help ghostty) | — |" "$REPO_ROOT/README.md"
  [ "$(grep -cF '`cmux`' "$REPO_ROOT/README.md" "$REPO_ROOT/CHEATSHEET.md" | awk -F: '{ s += $2 } END { print s }')" -eq 0 ]
  assert_file_absent "$REPO_ROOT/.claude/skills/artefiles/references/cmux.md"
}

@test "Zellij and cmux are named only where a stored cmux is migrated" {
  # .chezmoitemplates/modulesOfferedBefore records the modules an old config
  # was shown, cmux included, and stays as it is. The review files at the
  # root hold reviewers' notes, not sources.
  run grep -rIliE 'zellij|cmux' "$REPO_ROOT" \
    --exclude-dir=.git --exclude-dir=.jj --exclude-dir=.workspaces --exclude-dir=tests \
    --exclude=CHANGELOG.md --exclude=modulesOfferedBefore \
    --exclude=.review.org --exclude=.nvim-state.org
  [ "$(printf '%s\n' "$output" | sed "s#^$REPO_ROOT/##" | sort | tr '\n' ' ')" = ".chezmoi.toml.tmpl .chezmoitemplates/modules " ]
  if grep -rqi zellij "$REPO_ROOT/.chezmoi.toml.tmpl" "$REPO_ROOT/.chezmoitemplates/modules"; then return 1; fi
}

@test "a stored cmux reads as ghostty on apply" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["cmux","editor"]}'
  out=$(printf '{{ includeTemplate "modules" . }}' \
    | XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
      --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H")
  jq -e '. == ["ghostty","editor"]' <<< "$out"
  out=$(render '["cmux"]' "$DARWIN_TMPL")
  grep -qxF 'cask "ghostty"' <<< "$out"
}

@test "init rewrites a stored cmux to ghostty and keeps the module version" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\ncase "$*" in *login*) echo u ;; *) echo u@example.com ;; esac\n' > "$fake_bin/gh"
  chmod +x "$fake_bin/gh"
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["cmux","editor"]}'
  env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi init --config "$H/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$H"
  cfg="$H/.config/chezmoi/chezmoi.toml"
  sed -n 's/^modules = //p' "$cfg" | jq -e '. == ["ghostty","editor"]'
  grep -qx "modulesVersion = $(cat "$REPO_ROOT/.chezmoitemplates/modulesVersion")" "$cfg"
}

@test "an update offers herdr to a config that had cmux, starting from ghostty" {
  H=$(mk_fake_home)
  printf '[data]\n  name = "u"\n  email = "u@example.com"\n  modulesVersion = 2\n  modules = ["cmux"]\n' \
    > "$H/.config/chezmoi/chezmoi.toml"
  out=$(chezmoi_render "$H" .chezmoiscripts/run_before_offer-new-modules.sh.tmpl)
  grep -qxF "modules='[\"ghostty\"]'" <<< "$out"
  grep -qE '^unseen=\$\(printf .* herdr( |\))' <<< "$out"
}
