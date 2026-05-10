#!/usr/bin/env bats
# Tests for .chezmoiscripts/linux/run_onchange_install-gh.sh.tmpl

setup() {
  load 'helpers/setup'
}

@test "gh install script renders and shellchecks" {
  if ! command -v shellcheck > /dev/null 2>&1; then
    skip "shellcheck not available"
  fi
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/linux/run_onchange_install-gh.sh.tmpl)
  printf '%s\n' "$rendered" | shellcheck -
}

@test "every linux install script shellchecks after rendering" {
  if ! command -v shellcheck > /dev/null 2>&1; then
    skip "shellcheck not available"
  fi
  H=$(mk_fake_home)
  all=$(yq -r '.packages.darwin.modules | keys | .[]' "$REPO_ROOT/.chezmoidata/packages.yaml" \
        | jq -R . | jq -sc .)
  seed_chezmoi_config "$H" "$(jq -nc --argjson m "$all" '{modules:$m}')"
  for f in "$REPO_ROOT"/.chezmoiscripts/linux/*.sh "$REPO_ROOT"/.chezmoiscripts/linux/*.sh.tmpl; do
    [ -f "$f" ] || continue
    rel=${f#"$REPO_ROOT"/}
    out="$BATS_TEST_TMPDIR/$(basename "${rel%.tmpl}")"
    if [[ "$f" == *.tmpl ]]; then
      chezmoi_render "$H" "$rel" > "$out"
    else
      cp "$f" "$out"
    fi
    if ! shellcheck -S error "$out" 2>"$BATS_TEST_TMPDIR/err"; then
      echo "shellcheck failed on rendered $rel:" >&2
      cat "$BATS_TEST_TMPDIR/err" >&2
      return 1
    fi
  done
}

@test "gh install script is a no-op if local gh is already the latest version" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  rendered=$(chezmoi_render "$H" .chezmoiscripts/linux/run_onchange_install-gh.sh.tmpl)

  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin" "$BATS_TEST_TMPDIR/.local/bin"

  # Read the embedded latest tag from the rendered script — the script's
  # exit-early branch compares it against $LOCAL_GH --version, so we fake
  # gh to print that exact version.
  latest=$(printf '%s\n' "$rendered" \
    | grep -E "^# Latest gh tag:" \
    | sed -E 's/.*: v?([^ ]+).*/\1/')
  [ -n "$latest" ]

  printf '#!/bin/sh\nprintf "gh version %s (date)\\n" "$0_version"\n' \
    > "$BATS_TEST_TMPDIR/.local/bin/gh"
  # Use awk-friendly third field
  cat > "$BATS_TEST_TMPDIR/.local/bin/gh" <<EOF
#!/bin/sh
echo "gh version $latest (2026-01-01)"
EOF
  chmod +x "$BATS_TEST_TMPDIR/.local/bin/gh"

  # Fake curl that returns the latest tag JSON; if anything fetches the
  # download_url instead, the assertion below will catch it.
  cat > "$fake_bin/curl" <<EOF
#!/bin/sh
case "\$*" in
  *api.github.com/repos/cli/cli/releases/latest*)
    printf '"tag_name": "v%s"\n' "$latest"
    ;;
  *)
    echo "unexpected curl call: \$*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_bin/curl"

  run env PATH="$fake_bin:$BATS_TEST_TMPDIR/.local/bin:$PATH" \
        HOME="$BATS_TEST_TMPDIR" \
        sh -c "$rendered"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "up to date"
}
