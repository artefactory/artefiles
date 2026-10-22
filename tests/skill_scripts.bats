#!/usr/bin/env bats
# The artefiles skill's helper scripts, each on a fake home with chezmoi run for
# real and the other tools stubbed. The read-only ones change nothing; the
# others change something only with --apply.

setup() {
  load 'helpers/setup'
  S="$REPO_ROOT/.claude/skills/artefiles/scripts"
  H=$(mk_fake_home)
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
}

# in_home CMD... — run CMD with the fake home as HOME and the stubs first on PATH.
in_home() {
  run env HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
    PATH="$BIN:$PATH" GITHUB_TOKEN=set "$@"
}

# stub NAME BODY — a command NAME on PATH running the shell code BODY.
stub() {
  printf '#!/bin/sh\n%s\n' "$2" > "$BIN/$1"
  chmod +x "$BIN/$1"
}

@test "modules.sh lists the migrated modules and the guides to read" {
  seed_chezmoi_config "$H" '{"modules":["editor","data"]}'
  in_home sh "$S/modules.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Modules: editor data"* ]]
  [[ "$output" == *"/references/core.md"* ]]
  [[ "$output" == *"/references/data.md"* ]]
}

@test "modules.sh says so when the chezmoi source is not artefiles" {
  seed_chezmoi_config "$H" '{"modules":[]}'
  mkdir -p "$BATS_TEST_TMPDIR/other"
  sed -i.bak "s|^sourceDir = .*|sourceDir = \"$BATS_TEST_TMPDIR/other\"|" "$H/.config/chezmoi/chezmoi.toml"
  in_home sh "$S/modules.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not artefiles"* ]]
}

@test "drift.sh names each differing target with the commands that keep either side" {
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_apply "$H" --force
  in_home sh "$S/drift.sh"
  [[ "$output" == *"No drift"* ]]
  echo "# mine" >> "$H/.config/starship.toml"
  echo "# mine" >> "$H/.config/fish/config.fish"
  in_home sh "$S/drift.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *".config/starship.toml: differs"* ]]
  [[ "$output" == *"chezmoi re-add $H/.config/starship.toml"* ]]
  # config.fish comes from a template: re-add would skip it.
  [[ "$output" == *"config.fish.tmpl by hand, or: chezmoi merge $H/.config/fish/config.fish"* ]]
  grep -q '# mine' "$H/.config/starship.toml"
}

@test "diagnose.sh reports every section and the install backups" {
  seed_chezmoi_config "$H" '{"modules":[]}'
  mkdir -p "$H/.local/state/artefiles/backup-20261022-120000"
  stub gh 'exit 1'
  in_home sh "$S/diagnose.sh"
  [ "$status" -eq 0 ]
  for s in Tools Source GitHub "chezmoi doctor" Drift dotfiles_doctor "Install backups"; do
    [[ "$output" == *"## $s"* ]] || { echo "missing section $s" >&2; return 1; }
  done
  [[ "$output" == *"gh: not logged in"* ]]
  [[ "$output" == *"--restore $H/.local/state/artefiles/backup-20261022-120000"* ]]
}

@test "aliases.sh lists a tool's aliases and functions, and nothing of another tool" {
  seed_chezmoi_config "$H" '{"modules":[]}'
  in_home sh "$S/aliases.sh" eza
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^alias ll="eza '
  printf '%s\n' "$output" | grep -q '^alias lsize='
  in_home sh "$S/aliases.sh" fd
  printf '%s\n' "$output" | grep -q '^alias ff="fd --type f"'
  printf '%s\n' "$output" | grep -q '^function fbig'
  [ "$(printf '%s\n' "$output" | grep -c 'eza')" -eq 0 ]
  in_home sh "$S/aliases.sh" git
  printf '%s\n' "$output" | grep -q '^alias gs="git status"'
  [ "$(printf '%s\n' "$output" | grep -c '^alias ll=')" -eq 0 ]
}

@test "tool-info.sh finds the module by command or package name" {
  seed_chezmoi_config "$H" '{"modules":[]}'
  stub kubectl 'echo "Client Version: v1.34.1"'
  in_home sh "$S/tool-info.sh" kubectl
  [ "$status" -eq 0 ]
  [[ "$output" == *"kubectl: module kubernetes"* ]]
  [[ "$output" == *"installed: $BIN/kubectl, Client Version: v1.34.1"* ]]
  [[ "$output" == *"references/kubernetes.md"* ]]
  in_home sh "$S/tool-info.sh" ripgrep
  [[ "$output" == *"rg: module shell_tools"* ]]
  in_home sh "$S/tool-info.sh" mergiraf
  [[ "$output" == *"mergiraf: module core"* ]]
}

# release_source — a git source with tags v1, v2, v3, at v3.
release_source() {
  R="$BATS_TEST_TMPDIR/release"
  git init --quiet "$R"
  for v in v1 v2 v3; do
    echo "$v" > "$R/version"
    git -C "$R" add -A
    git -C "$R" -c user.email=t@e -c user.name=t -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet -m "$v"
    git -C "$R" -c tag.gpgsign=false tag "$v"
  done
  git -C "$R" checkout --quiet --detach v3
  stub chezmoi "case \"\$1\" in source-path) echo '$R' ;; status) ;; execute-template) echo '$H' ;; esac"
}

@test "rollback.sh prints the plan to the previous release, and moves only with --apply" {
  release_source
  in_home sh "$S/rollback.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"from v3 to v2"* ]]
  [ "$(cat "$R/version")" = v3 ]
  in_home sh "$S/rollback.sh" --apply
  [ "$status" -eq 0 ]
  [ "$(cat "$R/version")" = v2 ]
  [[ "$output" == *"No drift"* ]]
}

@test "upstream.sh shows the newest release and merges it into the fork only with --apply" {
  release_source
  U="$R"
  F="$BATS_TEST_TMPDIR/fork"
  git clone --quiet "$U" "$F"
  git -C "$F" checkout --quiet -B main v1
  git -C "$F" tag -d v2 v3 > /dev/null
  stub chezmoi "case \"\$1\" in source-path) echo '$F' ;; status) ;; execute-template) echo '$H' ;; esac"
  git -C "$F" remote set-url origin "$BATS_TEST_TMPDIR/my-fork.git"
  in_home env ARTEFILES_UPSTREAM="$U" sh "$S/upstream.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Newest release: v3, not merged"* ]]
  [ "$(cat "$F/version")" = v1 ]
  in_home env ARTEFILES_UPSTREAM="$U" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@e \
    sh "$S/upstream.sh" --apply
  [ "$status" -eq 0 ]
  [ "$(cat "$F/version")" = v3 ]
  in_home env ARTEFILES_UPSTREAM="$U" sh "$S/upstream.sh"
  [[ "$output" == *"already has v3"* ]]
}

@test "check-module.sh passes for every module and fails for an unknown one" {
  seed_chezmoi_config "$H" '{"modules":[]}'
  for m in $(prompt_module_names); do
    in_home sh "$S/check-module.sh" "$m" "$REPO_ROOT"
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
  done
  in_home sh "$S/check-module.sh" nosuchmodule "$REPO_ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ choice line"* ]]
}

@test "envrc-uv.sh prints the .envrc, and writes it only with --apply in a uv project" {
  P="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$P"
  in_home sh "$S/envrc-uv.sh" --nested
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | head -n 1)" = source_up ]
  [ "$(printf '%s\n' "$output" | tail -n 1)" = 'layout uv --inexact' ]
  in_home sh "$S/envrc-uv.sh" --apply "$P"
  [ "$status" -ne 0 ]
  [ ! -e "$P/.envrc" ]
  touch "$P/pyproject.toml" "$P/uv.lock"
  stub direnv 'exit 0'
  in_home sh "$S/envrc-uv.sh" --apply "$P"
  [ "$status" -eq 0 ]
  [ "$(cat "$P/.envrc")" = 'layout uv --inexact' ]
  in_home sh "$S/envrc-uv.sh" --apply --nested "$P"
  [ "$status" -ne 0 ]
  in_home sh "$S/envrc-uv.sh" --apply --nested --force "$P"
  [ "$(head -n 1 "$P/.envrc")" = source_up ]
}

@test "cloud-status.sh says who each CLI is signed in as, or what to run" {
  stub gcloud 'case "$*" in *account*) echo me@example.com ;; *project*) echo proj ;; esac'
  stub az 'exit 1'
  in_home sh "$S/cloud-status.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gcloud: me@example.com, project proj"* ]]
  [[ "$output" == *"az: not signed in: az login"* ]]
  [[ "$output" == *"kubectl: "* ]]
}

@test "containers-status.sh points at colima start when the daemon is down" {
  stub colima 'exit 1'
  stub docker 'exit 1'
  stub lazydocker 'exit 0'
  in_home sh "$S/containers-status.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"colima: stopped: colima start"* ]]
  [[ "$output" == *"docker: cannot reach a daemon"* ]]
  [[ "$output" == *"buildx: missing"* ]]
  [[ "$output" == *"lazydocker: installed"* ]]
}

@test "hooks-status.sh reports the template hooks and this repository's hooks" {
  stub prek 'exit 0'
  mkdir -p "$H/.git_template/hooks"
  : > "$H/.git_template/hooks/pre-commit"
  G="$BATS_TEST_TMPDIR/repo"
  git -c init.templateDir= init --quiet "$G"
  : > "$G/.pre-commit-config.yaml"
  cd "$G"
  in_home sh "$S/hooks-status.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"manager: prek"* ]]
  [[ "$output" == *"template pre-commit: present"* ]]
  [[ "$output" == *"template commit-msg: missing"* ]]
  [[ "$output" == *"this repository: hooks not installed: prek install"* ]]
}
