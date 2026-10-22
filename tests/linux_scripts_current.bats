#!/usr/bin/env bats
# The Linux install scripts that download a tool skip the download when the
# installed version is already the latest, and install when it is not. Every
# tool, curl included, is a stub that logs its calls.

setup() {
  load 'helpers/setup'
  H="$BATS_TEST_TMPDIR/h"
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$H" "$BIN"
  : > "$CALLS"
  # curl answers a GitHub "latest release" lookup with $LATEST; any other call
  # is a download, logged and failed so the script stops there.
  cat > "$BIN/curl" << STUB
#!/bin/sh
echo "curl \$*" >> "$CALLS"
case "\$*" in
  *api.github.com*releases/latest*) printf '{\n  "tag_name": "%s",\n}\n' "\$LATEST" ;;
  *) exit 22 ;;
esac
STUB
  chmod +x "$BIN/curl"
}

# tool NAME OUTPUT — a stub NAME that logs its arguments and prints OUTPUT.
tool() {
  printf '#!/bin/sh\necho "%s $*" >> "%s"\nprintf "%%s\\n" "%s"\n' "$1" "$CALLS" "$2" > "$BIN/$1"
  chmod +x "$BIN/$1"
}

script() {
  run env -i HOME="$H" PATH="$BIN:/usr/bin:/bin" LATEST="$LATEST" sh "$REPO_ROOT/.chezmoiscripts/linux/$1"
}

downloads() { grep -c '^curl' "$CALLS" | tr -d ' '; }

@test "git-extras: the latest version installed is kept, an older one is replaced" {
  LATEST=7.3.0
  tool git-extras 7.3.0
  script run_onchange_install-git-extras.sh
  [ "$status" -eq 0 ]
  [ "$(downloads)" -eq 1 ]
  : > "$CALLS"
  tool git-extras 7.2.0
  script run_onchange_install-git-extras.sh
  [ "$(downloads)" -eq 2 ]
}

@test "copilot: the latest version installed is kept, an older one is replaced" {
  LATEST=v1.2.3
  tool copilot "GitHub Copilot CLI 1.2.3"
  script run_onchange_20_install-copilot-cli.sh
  [ "$status" -eq 0 ]
  [ "$(grep -c 'gh.io/copilot-install' "$CALLS")" -eq 0 ]
  : > "$CALLS"
  tool copilot "GitHub Copilot CLI 1.2.2"
  script run_onchange_20_install-copilot-cli.sh
  grep -q '^curl .*gh.io/copilot-install' "$CALLS"
}

@test "rust: rustup updates only when an update is available" {
  LATEST=unused
  tool rustup "stable-aarch64-apple-darwin - Up to date : 1.90.0"
  script run_onchange_install-rust.sh
  [ "$status" -eq 0 ]
  [ "$(grep -c '^rustup update' "$CALLS")" -eq 0 ]
  tool rustup "stable-aarch64-apple-darwin - Update available : 1.89.0 -> 1.90.0"
  script run_onchange_install-rust.sh
  grep -q '^rustup update' "$CALLS"
}

@test "gcloud: an existing SDK is updated by gcloud itself, never downloaded again" {
  LATEST=unused
  mkdir -p "$H/.local/google-cloud-sdk/bin"
  printf '#!/bin/sh\necho "gcloud $*" >> "%s"\n' "$CALLS" > "$H/.local/google-cloud-sdk/bin/gcloud"
  chmod +x "$H/.local/google-cloud-sdk/bin/gcloud"
  script run_onchange_install-gcloud.sh
  [ "$status" -eq 0 ]
  grep -q '^gcloud components update --quiet' "$CALLS"
  [ "$(downloads)" -eq 0 ]
}
