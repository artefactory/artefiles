#!/usr/bin/env bats
# .chezmoi.toml.tmpl is rendered at `chezmoi init` time. A bug here is
# unrecoverable for new users (init fails before anything is installed).
# Stub out gh to verify the template parses, all `output` calls succeed, and
# the rendered TOML contains the expected fields.

setup() {
  load 'helpers/setup'
}

@test ".chezmoi.toml.tmpl renders with stubbed gh" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/gh" <<'EOF'
#!/bin/sh
case "$*" in
  *"--jq"*".login"*) echo "testuser" ;;
  *"--jq"*"email"*) echo "test@example.com" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$fake_bin/gh"

  H=$(mk_fake_home)
  rendered=$(env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi execute-template \
      --source "$REPO_ROOT" --destination "$H" \
      --init \
      --promptString "email=t@example.com" \
      --promptMultichoice "modules=editor,terminal" \
      < "$REPO_ROOT/.chezmoi.toml.tmpl")

  printf '%s\n' "$rendered" | grep -q '^name = "testuser"$'
  printf '%s\n' "$rendered" | grep -q '^email = '
  printf '%s\n' "$rendered" | grep -q '^modules = '
  printf '%s\n' "$rendered" | grep -q '^credentialHelper = '
}

@test ".chezmoi.toml.tmpl rendered output is valid TOML" {
  if ! command -v python3 > /dev/null 2>&1; then
    skip "python3 not available"
  fi

  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/gh" <<'EOF'
#!/bin/sh
case "$*" in
  *".login"*) echo "u" ;;
  *"email"*) echo "u@example.com" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$fake_bin/gh"

  H=$(mk_fake_home)
  rendered=$(env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$H/.config" HOME="$H" \
    chezmoi execute-template \
      --source "$REPO_ROOT" --destination "$H" \
      --init \
      --promptString "email=u@example.com" \
      --promptMultichoice "modules=git_advanced" \
      < "$REPO_ROOT/.chezmoi.toml.tmpl")

  printf '%s\n' "$rendered" | python3 -c '
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib
tomllib.loads(sys.stdin.read())
'
}
