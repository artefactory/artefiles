#!/usr/bin/env bats
# scripts/check-brew-packages.sh asks Homebrew whether every declared package
# exists. A stub brew stands in: the suite never touches the network.

setup() {
  load 'helpers/setup'
  SCRIPT="$REPO_ROOT/scripts/check-brew-packages.sh"
  PKGS="$BATS_TEST_TMPDIR/packages.yaml"
  cat > "$PKGS" << 'YAML'
packages:
  darwin:
    core:
      brews: [git]
      casks: [font-x]
    modules:
      a:
        brews: [bat, azure-cli]
        casks: []
      b:
        taps: [acme/tap]
        brews: [acme/tap/tool]
        casks: [app]
YAML
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # FORMULAE and CASKS (space-separated) say what the fake Homebrew knows.
  cat > "$BATS_TEST_TMPDIR/bin/brew" << 'STUB'
#!/bin/sh
[ "$1" = tap ] && exit "${TAPRC:-0}"
[ "$1" = info ] || exit 64
case "$2" in
  --formula) list=$FORMULAE; kind=formula ;;
  --cask) list=$CASKS; kind=cask ;;
esac
# NETFAIL (space-separated) names fail like an unreachable Homebrew.
case " $NETFAIL " in *" $3 "*) echo "Error: Could not resolve host: formulae.brew.sh" >&2; exit 1 ;; esac
case " $list " in *" $3 "*) exit 0 ;; esac
echo "Error: No available $kind with the name \"$3\"." >&2
exit 1
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/brew"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export SLEEP=0 NETFAIL=""
  export FORMULAE="git bat azure-cli acme/tap/tool" CASKS="font-x app"
}

@test "every package found: exit 0 and the count" {
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked 6 packages, 0 missing"* ]]
}

@test "a missing formula fails and is named" {
  FORMULAE="git bat acme/tap/tool"
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING formula azure-cli"* ]]
  [[ "$output" == *"1 missing"* ]]
}

@test "a brew that only exists as a cask fails and says so" {
  FORMULAE="git bat acme/tap/tool"
  CASKS="font-x app azure-cli"
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING formula azure-cli (it exists as a cask"* ]]
}

@test "every missing package is listed, not just the first" {
  FORMULAE="git"
  CASKS=""
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 1 ]
  for n in bat azure-cli acme/tap/tool font-x app; do [[ "$output" == *"$n"* ]]; done
}

@test "a package of an untrusted tap is looked up in the tap's files" {
  tap="$BATS_TEST_TMPDIR/tap"
  mkdir -p "$tap/Formula"
  : > "$tap/Formula/tool.rb"
  cat > "$BATS_TEST_TMPDIR/bin/brew" << STUB
#!/bin/sh
case "\$1" in
  tap) exit 0 ;;
  --repository) echo "$tap"; exit 0 ;;
esac
case "\$3" in
  acme/tap/tool) echo "Error: Refusing to load formula from untrusted tap acme/tap." >&2; exit 1 ;;
esac
exit 0
STUB
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 0 ]
  rm "$tap/Formula/tool.rb"
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING formula acme/tap/tool"* ]]
}

@test "a brew outage is inconclusive: exit 2, no MISSING" {
  NETFAIL="bat"
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 2 ]
  [[ "$output" == *"INCONCLUSIVE bat: Error: Could not resolve host"* ]]
  [[ "$output" != *"MISSING"* ]]
}

@test "a missing package wins over an outage: exit 1" {
  FORMULAE="git bat acme/tap/tool"
  NETFAIL="git"
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING formula azure-cli"* ]]
  [[ "$output" == *"INCONCLUSIVE git"* ]]
}

@test "no yq on PATH: exit 1 with a one-line install hint" {
  # A PATH of only a brew stub and the shell's own tools, with no yq.
  mkdir -p "$BATS_TEST_TMPDIR/noyq"
  cp "$BATS_TEST_TMPDIR/bin/brew" "$BATS_TEST_TMPDIR/noyq/brew"
  ln -s "$(command -v dirname)" "$BATS_TEST_TMPDIR/noyq/dirname"
  PATH="$BATS_TEST_TMPDIR/noyq" run /bin/sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: yq is required: install it with brew install yq" ]
}

@test "a tap that cannot be added: exit 1, not inconclusive" {
  TAPRC=1
  export TAPRC
  run sh "$SCRIPT" "$PKGS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: cannot add tap acme/tap"* ]]
}
