#!/bin/sh
# Set up pi with Artefactory's pi-kit (https://github.com/artefactory/pi-kit),
# the team's pi packages and defaults, by running the kit's own install.sh: the
# kit decides the package list and merges its defaults under the settings you
# already have. The after_ prefix and the zzzzzz name run it after every other
# script: it needs the pi install-pi.sh installs, nothing needs it, and its
# failure then keeps no other step from running. .chezmoiignore leaves it out
# unless the pi and pi_kit modules are selected and the email in chezmoi's data
# is an @artefact.com one.
#
# The installer is reached only once git can read the kit and each git package
# it lists without a prompt; without that access nothing is written.
#
# It installs once. A plain run_ script retries on every apply until the kit's
# source is in pi's settings, then writes the marker
# ${XDG_STATE_HOME:-~/.local/state}/artefiles/pi-kit.installed. With the marker
# it does nothing, even if the kit was removed since, so packages the kit adds
# later do not reach this machine. The installer merges the kit's defaults last
# and ignores a failed merge, which is therefore not retried.
set -eu

# ~/.local/bin holds fnm, jq and pi's launcher on Linux and may not be on this
# script's PATH.
PATH="$HOME/.local/bin:$PATH"

base="https://raw.githubusercontent.com/artefactory/pi-kit/main"
source_name="git:git@github.com:artefactory/pi-kit"
settings="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/settings.json"
# A relative XDG_STATE_HOME is invalid and ignored.
case ${XDG_STATE_HOME:-} in
  /*) state=$XDG_STATE_HOME ;;
  *) state=$HOME/.local/state ;;
esac
marker="$state/artefiles/pi-kit.installed"

[ ! -e "$marker" ] || exit 0

mark() {
  mkdir -p "${marker%/*}"
  : > "$marker"
}

skip() {
  echo "pi-kit: $1, so it is not set up this time; $2 and run 'chezmoi apply' again, or deselect the pi_kit module." >&2
  exit 0
}

# A package is a source string, or an object that carries it with filters.
configured() {
  [ -f "$settings" ] \
    && jq -e --arg kit "$source_name" \
      'any(.packages[]?; (if type == "object" then .source else . end) == $kit)' \
      "$settings" > /dev/null 2>&1
}

command -v jq > /dev/null 2>&1 || skip "it needs jq" "install jq"

if configured; then
  mark
  exit 0
fi

# The installer reads and merges ~/.pi/agent only, while pi writes to this
# folder when it is set.
if [ -n "${PI_CODING_AGENT_DIR:-}" ] && [ "$PI_CODING_AGENT_DIR" != "$HOME/.pi/agent" ]; then
  skip "PI_CODING_AGENT_DIR moves pi's settings and the kit's installer only handles ~/.pi/agent" "unset it"
fi

# The installer would stop half way on settings it cannot read.
if [ -s "$settings" ] && ! jq -e 'type == "object"' "$settings" > /dev/null 2>&1; then
  skip "${settings} is not a JSON object" "fix that file"
fi

for tool in git ssh curl fnm perl; do
  command -v "$tool" > /dev/null 2>&1 || skip "it needs ${tool}" "install ${tool}"
done

# pi's own minimum, the one install-pi.sh checks.
node_ok() {
  version=$(fnm exec --using=default node --version 2> /dev/null) || return 1
  version=${version#v}
  major=${version%%.*}
  minor=${version#*.}
  minor=${minor%%.*}
  case "$major.$minor" in
    *[!0-9.]* | .* | *.) return 1 ;;
  esac
  [ "$major" -gt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -ge 19 ]; }
}

node_ok || skip "it needs Node.js 22.19 or newer as fnm's default" \
  "run 'fnm install --lts; fnm default lts-latest'"

# Looked up as the installer will see it: it installs a missing pi with npm,
# which would stand beside the one the pi module manages.
fnm exec --using=default sh -c 'command -v pi' > /dev/null 2>&1 \
  || skip "pi is not installed" "install pi"

# bounded SECONDS COMMAND... runs COMMAND and kills its process group, with
# status 124, if it is still running after SECONDS. macOS has no timeout(1).
bounded() {
  perl -e '
    my $seconds = shift;
    my $pid = fork;
    die "fork: $!\n" unless defined $pid;
    if (!$pid) { setpgrp; exec @ARGV; exit 127 }
    $SIG{ALRM} = sub { kill "KILL", -$pid; waitpid $pid, 0; exit 124 };
    $SIG{INT} = $SIG{TERM} = sub { kill "TERM", -$pid; exit 130 };
    alarm $seconds;
    waitpid $pid, 0;
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
  ' "$@"
}

# The installer's own SSH test, except that an unknown host key is refused here:
# the installer would accept it and write it to known_hosts, so it only runs
# once ssh already trusts github.com.
answer=$(bounded 30 ssh -n -T -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UpdateHostKeys=no -o ConnectTimeout=10 git@github.com 2>&1) || true
case $answer in
  *"successfully authenticated"*) ;;
  *"Host key verification failed"*)
    skip "ssh does not trust github.com's host key" \
      "run 'ssh -T git@github.com' and accept the key after comparing it with GitHub's published fingerprints"
    ;;
  *)
    skip "GitHub does not accept an SSH key without a prompt, and its private packages need one (https://docs.github.com/en/authentication/connecting-to-github-with-ssh)" \
      "check 'ssh -T git@github.com'"
    ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Apart from the installer: it reads a packages.txt that lies beside it.
check="$work/check"
mkdir "$check"

curl --retry 2 --retry-delay 2 --connect-timeout 10 --max-time 30 -fsSL \
  -o "$check/packages.txt" "$base/packages.txt" \
  || skip "its package list could not be downloaded from ${base}/packages.txt" "check the connection"

# The ssh of git here and of pi in the installer: the one you configured, never
# prompting and never adding a host key. GIT_SSH alone is left to git, since
# GIT_SSH_COMMAND would override it.
if [ -n "${GIT_SSH_COMMAND:-}" ] || [ -z "${GIT_SSH:-}" ]; then
  ssh_command=${GIT_SSH_COMMAND:-$(git -C "$check" config --get core.sshCommand || true)}
  GIT_SSH_COMMAND="${ssh_command:-ssh} -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o ConnectTimeout=10"
  export GIT_SSH_COMMAND
fi

# readable SOURCE: git can read the repository of a pi package source, cloned
# from the URL pi derives from it and rewritten by your git config as the clone
# will be. Other sources need no check.
readable() {
  case $1 in
    https://* | http://* | ssh://* | git://*) repo=$1 ;;
    git:*) repo=${1#git:} ;;
    *) return 0 ;;
  esac
  # Without the @ref pi splits off the path.
  case $repo in
    *://*)
      scheme=${repo%%://*}
      rest=${repo#*://}
      authority=${rest%%/*}
      path=${rest#"$authority"}
      repo="$scheme://$authority${path%%@*}"
      ;;
    git@*:*)
      prefix=${repo%%:*}
      path=${repo#*:}
      repo="$prefix:${path%%@*}"
      ;;
    *) repo="https://${repo%%@*}" ;;
  esac
  bounded 30 env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS= \
    git -C "$check" ls-remote "$repo" HEAD < /dev/null > /dev/null \
    || skip "git cannot read ${repo} without a prompt, and the kit installs it" \
      "get access to it (check with 'git ls-remote ${repo}')"
}

readable "$source_name"
while read -r line || [ -n "$line" ]; do
  readable "$(printf '%s' "$line" | tr -d '\r')"
done < "$check/packages.txt"
rm -rf "$check"

# Through a file, not a pipe: sh has no pipefail, and a failed download would
# otherwise run a partial script.
if ! curl --retry 5 --retry-delay 2 --connect-timeout 10 --max-time 60 -fsSL \
  -o "$work/install.sh" "$base/install.sh"; then
  echo "pi-kit: could not download the installer from ${base}/install.sh." >&2
  exit 1
fi

echo "Setting up pi with Artefactory's pi-kit; its packages can take a few minutes."
# git must fail rather than wait for a password nobody sees coming.
status=0
GIT_TERMINAL_PROMPT=0 fnm exec --using=default sh "$work/install.sh" < /dev/null || status=$?
if [ "$status" -ne 0 ]; then
  echo "pi-kit: its installer failed (exit ${status}); the next 'chezmoi apply' runs it again." >&2
  exit "$status"
fi

if ! configured; then
  echo "pi-kit: its installer ended without adding ${source_name} to ${settings}." >&2
  exit 1
fi
mark
