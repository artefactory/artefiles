#!/usr/bin/env bats
# The terminal setup is the ghostty module: the Ghostty terminal with the shared
# config. `terminal` survives only as a legacy alias for ghostty so stored
# configs keep their Ghostty setup; `multiplexer` is gone. herdr_module.bats
# covers herdr, which is started by typing `herdr`; Ghostty opens the login
# shell.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
  PACKAGES="$REPO_ROOT/.chezmoidata/packages.yaml"
}

# `! cmd` never fails a bats test unless it is the last line; refute always does.
refute() { if "$@"; then return 1; fi; }

@test "packages.yaml has the ghostty cask, not terminal or multiplexer" {
  yq -e '.packages.darwin.modules.ghostty.casks | contains(["ghostty"])' "$PACKAGES"
  refute yq -e '.packages.darwin.modules | has("terminal")' "$PACKAGES"
  refute yq -e '.packages.darwin.modules | has("multiplexer")' "$PACKAGES"
}

@test "init prompt offers ghostty, not terminal or multiplexer" {
  names=$(prompt_module_names)
  printf '%s\n' "$names" | grep -qx ghostty
  if printf '%s\n' "$names" | grep -qxE 'terminal|multiplexer'; then return 1; fi
}

@test "no source file gates on the multiplexer module" {
  # .chezmoi.toml.tmpl is exempt: it drops the stored name at init.
  refute grep -rn 'multiplexer' "$REPO_ROOT/.chezmoiignore" "$REPO_ROOT/.chezmoiexternal.toml.tmpl" \
    "$PACKAGES" "$REPO_ROOT/dot_config/ghostty/config.tmpl"
}

@test "the shared Ghostty config applies for ghostty and the legacy terminal alias" {
  for m in ghostty terminal; do
    H=$(mk_fake_home "$BATS_TEST_TMPDIR/h-$m")
    seed_chezmoi_config "$H" "{\"modules\":[\"$m\"]}"
    chezmoi_managed "$H" | grep -qx '.config/ghostty/config'
  done
}

@test "the Ghostty config is absent when ghostty is not selected" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor"]}'
  if chezmoi_managed "$H" | grep -q '^\.config/ghostty'; then return 1; fi
}

@test "the Ghostty config no longer talks about a multiplexer" {
  refute grep -n -i 'multiplexer' "$REPO_ROOT/dot_config/ghostty/config.tmpl"
}

@test "macOS install script installs the Ghostty cask for ghostty, and nothing else of it" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["ghostty"]}'
  out=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  printf '%s\n' "$out" | grep -qx 'cask "ghostty"'
  if printf '%s\n' "$out" | grep -qiE 'zellij|cmux'; then return 1; fi
}

@test "init rewrites a stored terminal module to ghostty and drops multiplexer" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\ncase "$*" in *login*) echo u ;; *) echo u@example.com ;; esac\n' > "$fake_bin/gh"
  chmod +x "$fake_bin/gh"
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["terminal","editor","multiplexer"]}'

  env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi init --config "$H/.config/chezmoi/chezmoi.toml" \
    --source "$REPO_ROOT" --destination "$H"

  modules=$(grep '^modules = ' "$H/.config/chezmoi/chezmoi.toml" | sed 's/^modules = //')
  printf '%s' "$modules" | jq -e 'index("ghostty") != null and index("editor") != null and index("terminal") == null and index("multiplexer") == null'
}

@test "README documents ghostty, not terminal or multiplexer" {
  grep -qE '^\| `ghostty` \|' "$REPO_ROOT/README.md"
  refute grep -qE '^\| `(terminal|multiplexer)` \|' "$REPO_ROOT/README.md"
}

# ghostty_external [VAR=VALUE...] — 1 when the Linux externals, rendered with
# the ghostty module and only these display variables set, download Ghostty;
# else 0. The template is guarded by `eq .chezmoi.os "linux"`, so the guard is
# forced. Rendering asks the GitHub API for the release assets. A failed or
# empty render prints nothing and returns 1, so `-eq 0` cannot pass on it.
ghostty_external() {
  local out
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/ext-$RANDOM")
  seed_chezmoi_config "$H" '{"modules":["ghostty"]}'
  out=$(env -u DISPLAY -u WAYLAND_DISPLAY -u CODESPACES "$@" \
    XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < <(sed 's/eq \.chezmoi\.os "linux"/true/' "$REPO_ROOT/.chezmoiexternal.toml.tmpl")) \
    || { echo "render of the externals failed" >&2; return 1; }
  # The same sentinel as tests/externals.bats: the Linux branch rendered.
  grep -qF '[".local/bin/starship"]' <<< "$out" || { echo "externals lack starship" >&2; return 1; }
  grep -cxF '[".local/bin/ghostty"]' <<< "$out" || true
}

@test "on Linux, Ghostty is downloaded with an X11 or a Wayland session" {
  [ "$(ghostty_external DISPLAY=:0)" -eq 1 ]
  [ "$(ghostty_external WAYLAND_DISPLAY=wayland-0)" -eq 1 ]
}

@test "on Linux, Ghostty is skipped without a display and in a Codespace, as VS Code is" {
  n=$(ghostty_external)
  [ "$n" -eq 0 ]
  n=$(ghostty_external DISPLAY=:0 CODESPACES=true)
  [ "$n" -eq 0 ]
  # The rule is the one the VS Code install script applies.
  grep -qF '[ -n "${CODESPACES:-}" ] || { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; }' \
    "$REPO_ROOT/.chezmoiscripts/linux/run_install-vscode.sh"
}

@test "without a display the Ghostty config is still managed, and macOS still gets the cask" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["ghostty"]}'
  (
    unset DISPLAY WAYLAND_DISPLAY
    export CODESPACES=true
    chezmoi_managed "$H" | grep -qx '.config/ghostty/config'
    chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl | grep -qx 'cask "ghostty"'
  )
}
