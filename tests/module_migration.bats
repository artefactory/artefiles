#!/usr/bin/env bats
# A module list saved before shell_tools, cli_extras, rust and review existed has
# no modulesVersion. chezmoi re-renders the config only on `chezmoi init`, so apply
# and update must read such a list as if it held the modules split out of the
# always-installed set, or those tools silently stop being installed.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
  H=$(mk_fake_home)
  PKG=.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl
}

# render_effective DATA_JSON — the module list apply sees for a config holding DATA_JSON.
render_effective() {
  seed_chezmoi_config "$H" "$1"
  printf '{{ includeTemplate "modules" . }}' \
    | XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
      --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H"
}

@test "an old list gets the modules split out of the always-installed set" {
  run render_effective '{"modules":["editor"],"modulesVersion":null}'
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '. == ["editor","shell_tools","cli_extras","rust"]'
}

@test "an old list with git_advanced also gets review" {
  run render_effective '{"modules":["git_advanced"],"modulesVersion":null}'
  printf '%s' "$output" | jq -e 'index("review") != null'
}

@test "an old list reads colima as containers" {
  run render_effective '{"modules":["colima"],"modulesVersion":null}'
  printf '%s' "$output" | jq -e 'index("containers") != null and index("colima") == null'
}

@test "a current list is used as saved, so unchecking a tool module sticks" {
  run render_effective '{"modules":["git_advanced"],"modulesVersion":2}'
  printf '%s' "$output" | jq -e '. == ["git_advanced"]'
}

@test "apply on an old list still installs the tools through brew" {
  seed_chezmoi_config "$H" '{"modules":["git_advanced"],"modulesVersion":null}'
  out=$(XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < "$REPO_ROOT/$PKG")
  for pkg in bat eza fzf dust rust tuicr; do
    printf '%s\n' "$out" | grep -qx "brew \"$pkg\"" || { echo "missing brew $pkg" >&2; return 1; }
  done
}

@test "apply on a current list without the tool modules leaves them out" {
  seed_chezmoi_config "$H" '{"modules":["git_advanced"],"modulesVersion":2}'
  out=$(XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < "$REPO_ROOT/$PKG")
  for pkg in bat eza dust rust tuicr; do
    if printf '%s\n' "$out" | grep -qx "brew \"$pkg\""; then echo "unexpected brew $pkg" >&2; return 1; fi
  done
}

@test "apply on an old list with git_advanced keeps the tuicr config" {
  seed_chezmoi_config "$H" '{"modules":["git_advanced"],"modulesVersion":null}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/tuicr"
}

# init_with_stored DATA_JSON — re-run init over an existing config with empty answers.
init_with_stored() {
  seed_chezmoi_config "$H" "$1"
  run env -i HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$(dirname "$(command -v chezmoi)"):/usr/bin:/bin" \
    sh -c "printf '\n\n' | chezmoi init --no-tty --source '$REPO_ROOT' --config-path '$H/.config/chezmoi/chezmoi.toml' --destination '$H/dest' --exclude=externals"
  [ "$status" -eq 0 ]
}

@test "re-running init on an old list writes the migrated list and the version" {
  init_with_stored '{"modules":["git_advanced"],"modulesVersion":null}'
  grep -qx 'modulesVersion = 2' "$H/.config/chezmoi/chezmoi.toml"
  grep '^modules = ' "$H/.config/chezmoi/chezmoi.toml" | sed 's/^modules = //' \
    | jq -e '. == ["git_advanced","shell_tools","cli_extras","rust","review"]'
}

@test "re-running init on a current list keeps it as saved" {
  init_with_stored '{"modules":["editor"],"modulesVersion":2}'
  grep '^modules = ' "$H/.config/chezmoi/chezmoi.toml" | sed 's/^modules = //' | jq -e '. == ["editor"]'
}

@test "install.sh and the template read the same version" {
  [ "$(cat "$REPO_ROOT/.chezmoitemplates/modulesVersion")" -ge 2 ]
  grep -qF '.chezmoitemplates/modulesVersion' "$REPO_ROOT/install.sh"
}
