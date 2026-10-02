#!/usr/bin/env bats
# The terminal setup is one choice between two alternatives: ghostty (which
# brings zellij) or cmux. `terminal` survives only as a legacy alias for
# ghostty so stored configs keep their Ghostty setup; `multiplexer` is gone.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
  PACKAGES="$REPO_ROOT/.chezmoidata/packages.yaml"
}

# `! cmd` never fails a bats test unless it is the last line; refute always does.
refute() { if "$@"; then return 1; fi; }

@test "packages.yaml has ghostty (cask + zellij) and cmux, not terminal or multiplexer" {
  yq -e '.packages.darwin.modules.ghostty.casks | contains(["ghostty"])' "$PACKAGES"
  yq -e '.packages.darwin.modules.ghostty.brews | contains(["zellij"])' "$PACKAGES"
  yq -e '.packages.darwin.modules.cmux.casks | contains(["manaflow-ai/cmux/cmux"])' "$PACKAGES"
  refute yq -e '.packages.darwin.modules | has("terminal")' "$PACKAGES"
  refute yq -e '.packages.darwin.modules | has("multiplexer")' "$PACKAGES"
}

@test "init prompt offers ghostty and cmux, not terminal or multiplexer" {
  names=$(prompt_module_names)
  printf '%s\n' "$names" | grep -qx ghostty
  printf '%s\n' "$names" | grep -qx cmux
  if printf '%s\n' "$names" | grep -qxE 'terminal|multiplexer'; then return 1; fi
}

@test "no source file gates on the multiplexer module" {
  # .chezmoi.toml.tmpl is exempt: it drops the stored name at init.
  refute grep -rn 'multiplexer' "$REPO_ROOT/.chezmoiignore" "$REPO_ROOT/.chezmoiexternal.toml.tmpl" \
    "$PACKAGES" "$REPO_ROOT/dot_config/ghostty/config.tmpl"
}

@test "the shared Ghostty config applies for ghostty, cmux and the legacy terminal alias" {
  for m in ghostty cmux terminal; do
    H=$(mk_fake_home "$BATS_TEST_TMPDIR/h-$m")
    seed_chezmoi_config "$H" "{\"modules\":[\"$m\"]}"
    chezmoi_managed "$H" | grep -qx '.config/ghostty/config'
  done
}

@test "the Ghostty config is absent when neither terminal is selected" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor"]}'
  if chezmoi_managed "$H" | grep -q '^\.config/ghostty'; then return 1; fi
}

@test "the Ghostty config no longer talks about a multiplexer" {
  refute grep -n -i 'multiplexer' "$REPO_ROOT/dot_config/ghostty/config.tmpl"
}

@test "macOS install script brews zellij for ghostty and the cmux cask for cmux" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["ghostty"]}'
  out=$(chezmoi_render "$H" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  printf '%s\n' "$out" | grep -qx 'cask "ghostty"'
  printf '%s\n' "$out" | grep -qx 'brew "zellij"'
  if printf '%s\n' "$out" | grep -q 'cmux'; then return 1; fi

  H2=$(mk_fake_home "$BATS_TEST_TMPDIR/h2")
  seed_chezmoi_config "$H2" '{"modules":["cmux"]}'
  out=$(chezmoi_render "$H2" .chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl)
  printf '%s\n' "$out" | grep -qx 'cask "manaflow-ai/cmux/cmux"'
  if printf '%s\n' "$out" | grep -qE 'zellij|"ghostty"'; then return 1; fi
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

@test "README documents ghostty, cmux and the removed multiplexer module" {
  grep -qE '^\| `ghostty` \|' "$REPO_ROOT/README.md"
  grep -qE '^\| `cmux` \|' "$REPO_ROOT/README.md"
  refute grep -qE '^\| `(terminal|multiplexer)` \|' "$REPO_ROOT/README.md"
  grep -qi 'multiplexer.*ghostty\|ghostty.*multiplexer' "$REPO_ROOT/README.md"
}
