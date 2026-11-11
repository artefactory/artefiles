#!/usr/bin/env bats
# The Linux git-extras install stops with a clear message when it cannot read
# the latest version, instead of downloading from a URL with an empty tag.

setup() {
  load 'helpers/setup'
  SCRIPT="$REPO_ROOT/.chezmoiscripts/linux/run_onchange_install-git-extras.sh"
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/curl-calls"
  mkdir -p "$BIN" "$BATS_TEST_TMPDIR/home"
  : > "$CALLS"
}

# fake_curl STATUS [BODY] — a curl that logs its URL, prints BODY and exits STATUS.
fake_curl() {
  printf '%s\n' "$2" > "$BATS_TEST_TMPDIR/curl-body"
  cat > "$BIN/curl" << EOF
#!/bin/sh
for a in "\$@"; do case "\$a" in http*) echo "\$a" >> "$CALLS" ;; esac; done
cat "$BATS_TEST_TMPDIR/curl-body"
exit $1
EOF
  chmod +x "$BIN/curl"
}

# fake_git_extras VERSION — an installed git-extras that reports VERSION.
fake_git_extras() {
  printf '#!/bin/sh\necho %s\n' "$1" > "$BIN/git-extras"
  chmod +x "$BIN/git-extras"
}

run_script() {
  HOME="$BATS_TEST_TMPDIR/home" PATH="$BIN:$PATH" run sh "$SCRIPT"
}

@test "a failed API request stops the install before any download" {
  fake_curl 22 ''
  run_script
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: failed to fetch the latest git-extras version"* ]]
  [ "$(wc -l < "$CALLS")" -eq 1 ]
  [[ "$output" != *"Downloading from"* ]]
}

@test "an API answer without a tag stops the install before any download" {
  fake_curl 0 '{"message": "API rate limit exceeded"}'
  run_script
  [ "$status" -eq 1 ]
  [[ "$output" == *"names no latest git-extras version"* ]]
  [ "$(wc -l < "$CALLS")" -eq 1 ]
}

@test "the latest tag is read and an installed copy at that version is kept (control)" {
  fake_curl 0 '  "tag_name": "7.4.0",'
  fake_git_extras 7.4.0
  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"Latest git-extras version: 7.4.0"* ]]
  [[ "$output" == *"already installed"* ]]
}
