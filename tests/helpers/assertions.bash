#!/usr/bin/env bash
# Common assertions for bats tests. Keep messages specific so failures
# point straight at the broken invariant.

assert_file_exists() {
  if [ ! -e "$1" ]; then
    printf 'expected file to exist: %s\n' "$1" >&2
    return 1
  fi
}

assert_file_absent() {
  if [ -e "$1" ]; then
    printf 'expected file to be absent: %s\n' "$1" >&2
    return 1
  fi
}

assert_valid_json() {
  if ! jq -e . "$1" >/dev/null 2>&1; then
    printf 'invalid JSON: %s\n' "$1" >&2
    jq . "$1" >&2 || true
    return 1
  fi
}

assert_jq_key() {
  local file="$1" key="$2" expected="$3"
  local got; got=$(jq -r "$key" "$file")
  if [ "$got" != "$expected" ]; then
    printf 'jq %s in %s: expected %q, got %q\n' "$key" "$file" "$expected" "$got" >&2
    return 1
  fi
}

# assert_idempotent H — re-applying changes nothing.
assert_idempotent() {
  local h="$1"
  local out; out=$(chezmoi_diff "$h")
  if [ -n "$out" ]; then
    printf 'chezmoi diff non-empty after apply (not idempotent):\n%s\n' "$out" >&2
    return 1
  fi
}

# assert_no_override H REL_PATH MARKER
#   Edit a chezmoi-managed file, re-apply, confirm the edit survives.
#   Only meaningful for `create_`-prefixed files — `chezmoi apply` will
#   overwrite anything else.
assert_no_override() {
  local h="$1" rel="$2" marker="$3"
  printf '\n// %s\n' "$marker" >>"$h/$rel"
  chezmoi_apply "$h" >/dev/null
  if ! grep -qF "$marker" "$h/$rel"; then
    printf 'create_ override-protection broken: %s lost marker after re-apply\n' "$rel" >&2
    return 1
  fi
}
