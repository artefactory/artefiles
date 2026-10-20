#!/usr/bin/env bats
# release.yaml's first step finds the merged pull request from the pushed
# commit. Right after a rebase merge GitHub may not have linked the commit yet,
# so the step must ask again instead of failing or releasing nothing.

setup() {
  load 'helpers/setup'
  STEP="$BATS_TEST_TMPDIR/gate.sh"
  yq -r '.jobs.release.steps[] | select(.name == "Look for the release label on the merged pull request") | .run' \
    "$REPO_ROOT/.github/workflows/release.yaml" > "$STEP"
  [ -s "$STEP" ]
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  COUNT="$BATS_TEST_TMPDIR/count"
  echo 0 > "$COUNT"
  OUT="$BATS_TEST_TMPDIR/github_output"
  : > "$OUT"
  # sleep returns at once; gh fails or answers [] $LINKED_AFTER times, then
  # answers one pull request carrying $LABELS. Every lookup is one gh call.
  printf '#!/bin/sh\nexit 0\n' > "$BIN/sleep"
  cat > "$BIN/gh" << 'EOF'
#!/bin/sh
n=$(($(cat "$COUNT") + 1))
echo "$n" > "$COUNT"
if [ "$n" -le "$LINKED_AFTER" ]; then
  [ "$FAIL_MODE" = error ] && { echo "unexpected end of JSON input" >&2; exit 1; }
  echo '[]'
  exit 0
fi
printf '[{"number":1,"labels":[{"name":"%s"}]}]\n' "$LABELS"
EOF
  chmod +x "$BIN/sleep" "$BIN/gh"
}

run_gate() {
  run env PATH="$BIN:$PATH" COUNT="$COUNT" GITHUB_OUTPUT="$OUT" RUNNER_TEMP="$BATS_TEST_TMPDIR" EVENT=push REF=refs/heads/main \
    REPO=o/r SHA=abc "$@" bash -e -o pipefail "$STEP"
}

@test "a lookup that fails before GitHub links the commit is asked again, then releases" {
  run_gate LINKED_AFTER=2 FAIL_MODE=error LABELS=release
  [ "$status" -eq 0 ]
  grep -qx 'release=true' "$OUT"
}

@test "an empty answer before GitHub links the commit is asked again, then releases" {
  run_gate LINKED_AFTER=3 FAIL_MODE=empty LABELS=release
  [ "$status" -eq 0 ]
  grep -qx 'release=true' "$OUT"
}

@test "a pull request without the label releases nothing" {
  run_gate LINKED_AFTER=0 FAIL_MODE=empty LABELS="bug"
  [ "$status" -eq 0 ]
  grep -qx 'release=false' "$OUT"
}

@test "a commit no pull request is linked to releases nothing, with a warning" {
  run_gate LINKED_AFTER=99 FAIL_MODE=empty LABELS=release
  [ "$status" -eq 0 ]
  grep -qx 'release=false' "$OUT"
  [[ "$output" == *"::warning::no pull request is linked to abc"* ]]
}

@test "the labels come from the same answer as the count: one gh call once linked" {
  run_gate LINKED_AFTER=2 FAIL_MODE=empty LABELS=release
  [ "$status" -eq 0 ]
  [ "$(cat "$COUNT")" -eq 3 ]
}
