#!/usr/bin/env bats
# pi-kit, the team's pi packages and defaults, set up by its own installer from
# .chezmoiscripts/run_after_zzzzzz_install-pikit.sh. Every tool is a stub: no network,
# no real installer, no real home.

setup() {
  load 'helpers/setup'
  unset PI_CODING_AGENT_DIR
  SCRIPT="$REPO_ROOT/.chezmoiscripts/run_after_zzzzzz_install-pikit.sh"
  KIT="git:git@github.com:artefactory/pi-kit"
  H="$BATS_TEST_TMPDIR/home"
  SETTINGS="$H/.pi/agent/settings.json"
  BIN="$BATS_TEST_TMPDIR/bin"
  NODEBIN="$BATS_TEST_TMPDIR/node-bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  MARKER="$H/.local/state/artefiles/pi-kit.installed"
  mkdir -p "$H/.pi/agent" "$BATS_TEST_TMPDIR/tmp"
}

settings() { printf '%s\n' "$1" > "$SETTINGS"; }

# kit_script [-TOOL...] — run the script with a PATH of stubs, each logging its
# calls to $CALLS; -TOOL leaves that tool out. pi stands only on the PATH
# `fnm exec` gives, as an npm install of it does. The curl stub writes a fake
# installer that records how it was run and adds the kit to the settings. Knobs:
# SSH_FAIL, SSH_UNKNOWN_HOST, CURL_FAIL (the installer's download),
# LIST_FAIL (the package list's), GIT_FAIL and GIT_HANG (a pattern of the
# repository ls-remote refuses or never answers), SSH_CONFIG (the user's
# core.sshCommand), NODE_FAIL, NODE_VERSION, INSTALL_STATUS (the installer's
# exit status, before it adds the kit), NO_ADD (it exits 0 without adding it),
# XDG_STATE_HOME.
kit_script() {
  rm -rf "$BIN" "$NODEBIN"
  mkdir -p "$BIN" "$NODEBIN"
  : > "$CALLS"
  for real in mktemp rm cat head grep jq sh mv mkdir tr env perl sleep; do ln -sf "$(command -v "$real")" "$BIN/$real"; done
  printf '#!/bin/sh\n' > "$NODEBIN/pi"
  cat > "$BIN/git" << STUB
#!/bin/sh
echo "git \$*" >> "$CALLS"
[ "\$3" = config ] && { [ -n "\$SSH_CONFIG" ] && echo "\$SSH_CONFIG"; exit; }
echo "GIT_SSH_COMMAND:\$GIT_SSH_COMMAND" >> "$CALLS"
echo "prompts:\$GIT_TERMINAL_PROMPT,\$GIT_ASKPASS" >> "$CALLS"
if [ -n "\$GIT_HANG" ]; then case \$4 in *"\$GIT_HANG"*) sleep 120 ;; esac; fi
if [ -n "\$GIT_FAIL" ]; then case \$4 in *"\$GIT_FAIL"*) exit 128 ;; esac; fi
STUB
  cat > "$BIN/ssh" << STUB
#!/bin/sh
echo "ssh \$*" >> "$CALLS"
if [ -n "\$SSH_FAIL" ]; then
  echo "git@github.com: Permission denied (publickey)." >&2
  exit 255
fi
if [ -n "\$SSH_UNKNOWN_HOST" ]; then
  echo "Host key verification failed." >&2
  exit 255
fi
echo "Hi someone! You've successfully authenticated, but GitHub does not provide shell access." >&2
exit 1
STUB
  cat > "$BIN/fnm" << STUB
#!/bin/sh
echo "fnm \$*" >> "$CALLS"
shift 2
if [ "\$1" = node ]; then
  [ -z "\$NODE_FAIL" ] && echo "v\${NODE_VERSION:-22.19.0}"
  exit
fi
PATH="$NODEBIN:\$PATH" exec "\$@"
STUB
  cat > "$BIN/curl" << STUB
#!/bin/sh
echo "curl \$*" >> "$CALLS"
out=
while [ \$# -gt 0 ]; do [ "\$1" = -o ] && out=\$2; url=\$1; shift; done
case \$url in
  */packages.txt)
    [ -n "\$LIST_FAIL" ] && exit 22
    printf '%s\n' '# comment' '' 'npm:pi-ask-user' \
      'git:github.com/example/public@v1' 'git:git@github.com:artefactory/private' > "\$out"
    exit
    ;;
esac
[ -n "\$CURL_FAIL" ] && exit 22
cat > "\$out" << 'INSTALLER'
echo "installer \$0" >> "$CALLS"
dir=\${0%/*}
set -- "\$dir"/*
echo "files beside it: \$#" >> "$CALLS"
echo "stdin:\$(head -n 1)" >> "$CALLS"
echo "PATH:\$PATH" >> "$CALLS"
echo "GIT_TERMINAL_PROMPT:\$GIT_TERMINAL_PROMPT" >> "$CALLS"
echo "installer ssh:\$GIT_SSH_COMMAND" >> "$CALLS"
echo "kit installer output"
[ "\${INSTALL_STATUS:-0}" -eq 0 ] || exit "\$INSTALL_STATUS"
[ -n "\$NO_ADD" ] && exit 0
[ -s "\$HOME/.pi/agent/settings.json" ] || echo '{}' > "\$HOME/.pi/agent/settings.json"
jq '.packages += ["git:git@github.com:artefactory/pi-kit"]' "\$HOME/.pi/agent/settings.json" > "\$HOME/new.json"
mv "\$HOME/new.json" "\$HOME/.pi/agent/settings.json"
INSTALLER
STUB
  chmod +x "$BIN/git" "$BIN/ssh" "$BIN/fnm" "$BIN/curl" "$NODEBIN/pi"
  for t in "$@"; do rm "$BIN/${t#-}" 2> /dev/null || rm "$NODEBIN/${t#-}"; done
  echo "from the apply" > "$BATS_TEST_TMPDIR/stdin"
  run env -i HOME="$H" PATH="$BIN" TMPDIR="$BATS_TEST_TMPDIR/tmp" \
    SSH_FAIL="${SSH_FAIL:-}" CURL_FAIL="${CURL_FAIL:-}" NODE_FAIL="${NODE_FAIL:-}" \
    NODE_VERSION="${NODE_VERSION:-}" INSTALL_STATUS="${INSTALL_STATUS:-}" NO_ADD="${NO_ADD:-}" \
    PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-}" XDG_STATE_HOME="${XDG_STATE_HOME:-}" \
    SSH_UNKNOWN_HOST="${SSH_UNKNOWN_HOST:-}" LIST_FAIL="${LIST_FAIL:-}" \
    GIT_FAIL="${GIT_FAIL:-}" GIT_HANG="${GIT_HANG:-}" SSH_CONFIG="${SSH_CONFIG:-}" \
    /bin/sh "$SCRIPT" < "$BATS_TEST_TMPDIR/stdin"
}

calls() { grep -c -e "$1" "$CALLS" || true; }

# skipped WORD — the apply goes on, the message names WORD, the installer is
# neither fetched nor run and no marker is written.
skipped() {
  [ "$status" -eq 0 ] || {
    echo "status $status: $output" >&2
    return 1
  }
  [[ "$output" == *"pi-kit: "*"$1"*"chezmoi apply"* ]] || {
    echo "no message on $1: $output" >&2
    return 1
  }
  [ "$(calls '^curl.*install\.sh')" -eq 0 ]
  [ "$(calls '^installer /')" -eq 0 ]
  [ ! -e "$MARKER" ]
}

@test "the installer is downloaded from the kit's repository and run alone in its own directory" {
  kit_script
  [ "$status" -eq 0 ]
  grep -qE '^curl .*-f.* https://raw\.githubusercontent\.com/artefactory/pi-kit/main/install\.sh$' "$CALLS"
  [ "$(calls '^installer /')" -eq 1 ]
  # Nothing beside it: the installer would read a packages.txt found there.
  grep -qx 'files beside it: 1' "$CALLS"
  # With fnm's default Node, off the apply's stdin, and git never prompting.
  [ "$(calls '^fnm exec --using=default sh .*/install\.sh$')" -eq 1 ]
  grep -qx 'stdin:' "$CALLS"
  grep -qx 'GIT_TERMINAL_PROMPT:0' "$CALLS"
  [[ "$output" == *"kit installer output"* ]]
  # The directory goes with the script.
  dir=$(sed -n 's|^installer /|/|p' "$CALLS")
  [ -n "$dir" ] && [ ! -e "${dir%/*}" ]
}

@test "the installer sees ~/.local/bin first" {
  kit_script
  [[ "$(grep '^PATH:' "$CALLS")" == "PATH:$NODEBIN:$H/.local/bin:"* ]]
}

@test "the SSH test never prompts, bounds the connection and runs before the download" {
  kit_script
  line=$(grep '^ssh ' "$CALLS")
  for option in "-n" "-o BatchMode=yes" "-o StrictHostKeyChecking=yes" \
    "-o UpdateHostKeys=no" "-o ConnectTimeout=10" "git@github.com"; do
    [[ " $line " == *" $option "* ]] || {
      echo "missing $option: $line" >&2
      return 1
    }
  done
  [ "$(grep -n '^ssh ' "$CALLS" | cut -d: -f1)" -lt "$(grep -n '^curl ' "$CALLS" | head -n 1 | cut -d: -f1)" ]
}

@test "an unknown github.com host key is not accepted: the setup is skipped" {
  SSH_UNKNOWN_HOST=1 kit_script
  skipped "host key"
  [ "$(calls 'accept-new')" -eq 0 ]
}

@test "every git source is read before the installer is downloaded, from the URL pi clones" {
  kit_script
  [ "$status" -eq 0 ]
  [ "$(sed -n 's/^git -C [^ ]* ls-remote \(.*\) HEAD$/\1/p' "$CALLS" | tr '\n' ' ')" = \
    "git@github.com:artefactory/pi-kit https://github.com/example/public git@github.com:artefactory/private " ]
  [ "$(calls '^prompts:0,$')" -eq 3 ]
  last=$(grep -n ' ls-remote ' "$CALLS" | tail -n 1 | cut -d: -f1)
  [ "$last" -lt "$(grep -n '^curl.*install\.sh' "$CALLS" | cut -d: -f1)" ]
}

@test "a repository git cannot read skips the setup and writes nothing" {
  for repo in pi-kit example/public artefactory/private; do
    before=$(find "$H" | sort)
    GIT_FAIL=$repo kit_script
    skipped "cannot read" || return 1
    [[ "$output" == *"$repo"* ]]
    [ "$(find "$H" | sort)" = "$before" ]
  done
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/tmp")" ]
}

@test "a git that never answers is killed and the setup skipped" {
  SECONDS=0
  GIT_HANG=artefactory/private kit_script
  skipped "cannot read"
  [ "$SECONDS" -lt 60 ]
}

@test "a package list that cannot be downloaded skips the setup" {
  LIST_FAIL=1 kit_script
  skipped "package list"
}

@test "git and the installer use the user's ssh command, strict and without prompts" {
  options="-o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o ConnectTimeout=10"
  SSH_CONFIG="ssh -i /keys/work" kit_script
  [ "$(calls "^GIT_SSH_COMMAND:ssh -i /keys/work $options\$")" -eq 3 ]
  grep -qx "installer ssh:ssh -i /keys/work $options" "$CALLS"
  rm "$MARKER"
  settings '{}'
  kit_script
  grep -qx "installer ssh:ssh $options" "$CALLS"
}

@test "a success writes the marker, and the kit is never installed again" {
  kit_script
  [ -f "$MARKER" ]
  settings '{}'
  kit_script
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -s "$CALLS" ]
}

@test "the marker follows an absolute XDG_STATE_HOME only" {
  XDG_STATE_HOME="$H/state" kit_script
  [ -f "$H/state/artefiles/pi-kit.installed" ]
  settings '{}'
  XDG_STATE_HOME=relative kit_script
  [ -f "$MARKER" ]
}

@test "with the kit in pi's settings nothing runs, as a string or as an object" {
  for entry in "\"$KIT\"" "{\"source\":\"$KIT\",\"skills\":[]}"; do
    settings "{\"packages\":[\"npm:other\",$entry]}"
    rm -f "$MARKER"
    kit_script
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -s "$CALLS" ] || {
      echo "$entry: $(cat "$CALLS")" >&2
      return 1
    }
    [ -f "$MARKER" ]
  done
}

@test "a configured kit needs neither pi, ssh nor the network" {
  settings "{\"packages\":[\"$KIT\"]}"
  kit_script -pi -ssh -curl -fnm -git
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "other packages of the kit do not count as the kit" {
  settings "{\"packages\":[\"$KIT-extra\",\"git:git@github.com:artefactory/pi-litellm\"]}"
  kit_script
  [ "$status" -eq 0 ]
  [ "$(calls '^installer /')" -eq 1 ]
}

@test "without jq, git, ssh, curl, fnm or pi the apply goes on and says what is missing" {
  for tool in jq git ssh curl fnm perl; do
    kit_script "-$tool"
    skipped "it needs $tool" || return 1
  done
  kit_script -pi
  skipped "pi is not installed"
}

@test "without a default Node 22.19 or newer the setup is skipped" {
  NODE_FAIL=1 kit_script
  skipped "22.19"
  NODE_VERSION=22.18.9 kit_script
  skipped "22.19"
  NODE_VERSION=23.0.0 kit_script
  [ "$(calls '^installer /')" -eq 1 ]
}

@test "without GitHub SSH access the setup is skipped" {
  SSH_FAIL=1 kit_script
  skipped "SSH key"
}

@test "settings that are not a JSON object are left alone and the installer does not run" {
  for bad in 'not json' '["a"]' '{"packages":'; do
    settings "$bad"
    kit_script
    skipped "not a JSON object" || return 1
    [ "$(cat "$SETTINGS")" = "$bad" ]
  done
}

@test "a PI_CODING_AGENT_DIR elsewhere skips the setup, unless the kit is configured there" {
  PI_CODING_AGENT_DIR="$H/other" kit_script
  skipped "PI_CODING_AGENT_DIR"
  mkdir -p "$H/other"
  rm -f "$MARKER"
  printf '{"packages":["%s"]}\n' "$KIT" > "$H/other/settings.json"
  PI_CODING_AGENT_DIR="$H/other" kit_script
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -f "$MARKER"
  PI_CODING_AGENT_DIR="$H/.pi/agent" kit_script
  [ "$(calls '^installer /')" -eq 1 ]
}

@test "an empty settings file does not block the setup" {
  : > "$SETTINGS"
  kit_script
  [ "$status" -eq 0 ]
  [ "$(calls '^installer /')" -eq 1 ]
}

@test "a failed download fails the apply and runs nothing" {
  CURL_FAIL=1 kit_script
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not download"* ]]
  [ "$(calls '^installer /')" -eq 0 ]
}

@test "a failed installer fails the apply with its status, and the next apply runs it again" {
  settings '{"packages":["npm:pi-ask-user"],"theme":"mine"}'
  INSTALL_STATUS=7 kit_script
  [ "$status" -eq 7 ]
  [ ! -e "$MARKER" ]
  [[ "$output" == *"kit installer output"*"exit 7"* ]]
  kit_script
  [ "$status" -eq 0 ]
  [ "$(calls '^installer /')" -eq 1 ]
  [ "$(jq -r .theme "$SETTINGS")" = mine ]
  # Done: the apply after that touches nothing.
  kit_script
  [ "$status" -eq 0 ]
  [ ! -s "$CALLS" ]
}

@test "an installer that exits 0 without adding the kit fails the apply" {
  NO_ADD=1 kit_script
  [ "$status" -eq 1 ]
  [ ! -e "$MARKER" ]
  [[ "$output" == *"without adding $KIT"* ]]
}

@test "chezmoi runs the scripts in the order Homebrew, Node.js, pi, pi-kit" {
  # The repository's script names with logging bodies, applied by chezmoi.
  src="$BATS_TEST_TMPDIR/source"
  h=$(mk_fake_home "$BATS_TEST_TMPDIR/order-home")
  : > "$CALLS"
  for f in darwin/run_onchange_darwin-install-packages.sh.tmpl run_onchange_after_install-node.sh \
    run_after_install-pi.sh run_after_zzzzzz_install-pikit.sh; do
    [ -f "$REPO_ROOT/.chezmoiscripts/$f" ]
    mkdir -p "$(dirname "$src/.chezmoiscripts/$f")"
    printf '#!/bin/sh\necho "%s" >> "%s"\n' "$f" "$CALLS" > "$src/.chezmoiscripts/$f"
  done
  : > "$h/.config/chezmoi/chezmoi.toml"
  HOME="$h" XDG_CONFIG_HOME="$h/.config" chezmoi apply --source "$src" --destination "$h" \
    --config "$h/.config/chezmoi/chezmoi.toml" --persistent-state "$h/state.boltdb"
  [ "$(tr '\n' ' ' < "$CALLS")" = "darwin/run_onchange_darwin-install-packages.sh.tmpl run_onchange_after_install-node.sh run_after_install-pi.sh run_after_zzzzzz_install-pikit.sh " ]
}
