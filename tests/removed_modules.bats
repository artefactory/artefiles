#!/usr/bin/env bats
# The aerospace, onepassword and agent_skills modules are gone: no package
# entry, config, script, prompt choice, ignore gate, doc or test refers to them.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
  PATTERN='aerospace|onepassword|1password|agent[_-]skills'
}

# grep_tree PATTERN [extra grep args] — search the source tree, hidden files
# included, minus VCS/agent state, the changelog and the tests directory.
grep_tree() {
  local pattern="$1"
  shift
  grep -rIiE "$pattern" "$REPO_ROOT" \
    --exclude-dir=.git --exclude-dir=.jj --exclude-dir=.workspaces \
    --exclude-dir=.claude --exclude-dir=tests --exclude=CHANGELOG.md "$@"
}

@test "packages.yaml has no aerospace or onepassword module" {
  ! yq -e '.packages.darwin.modules | has("aerospace") or has("onepassword")' \
    "$REPO_ROOT/.chezmoidata/packages.yaml"
}

@test "the init prompt does not offer the removed modules" {
  prompt=$(prompt_module_names)
  [ -n "$prompt" ]
  if printf '%s\n' "$prompt" | grep -qE 'aerospace|onepassword|agent_skills'; then return 1; fi
}

@test "the removed modules' files are gone" {
  for f in .chezmoidata/agent_skills.yaml \
    .chezmoiscripts/run_zzz_install-agent-skills.sh.tmpl \
    .chezmoiscripts/linux/run_onchange_install-1password-cli.sh.tmpl \
    dot_config/aerospace; do
    assert_file_absent "$REPO_ROOT/$f"
  done
}

@test "no reference to the removed modules remains outside the tests" {
  ! grep_tree "$PATTERN"
}

@test "no test refers to the removed modules" {
  ! grep -rIiE 'aerospace|onepassword|agent[_-]skills' "$REPO_ROOT/tests" \
    --exclude=removed_modules.bats
}

@test "a config that still lists the removed modules applies cleanly" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["aerospace","onepassword","agent_skills","atuin"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/atuin"
  assert_file_absent "$H/.config/aerospace"
}
