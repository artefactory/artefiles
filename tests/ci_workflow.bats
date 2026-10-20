#!/usr/bin/env bats
# The CI install job must never report a missing chezmoi as passing, and must
# never let chezmoi run the scripts or externals that install packages.

setup() {
  load 'helpers/setup'
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
}

# step NAME — the shell of the install job's step NAME.
step() {
  yq -r ".jobs.install.steps[] | select(.name == \"$1\") | .run" "$CI_YML"
}

@test "the installer is not run from an empty command substitution" {
  [ -n "$(step "install chezmoi")" ]
  if step "install chezmoi" | grep -v '^[[:space:]]*#' | grep -qF 'sh -c "$(curl'; then return 1; fi
}

@test "the step fails when chezmoi is not installed afterwards" {
  last=$(step "install chezmoi" | grep -v '^[[:space:]]*$' | tail -1)
  [[ "$last" =~ chezmoi\"?\ --version ]]
}

@test "the chezmoi CI puts first on PATH skips scripts on apply and update and externals everywhere" {
  run step "never run scripts or download externals"
  # The flag goes first: after --version, chezmoi would read it as a command.
  [[ "$output" == *'apply | update) exec "$RUNNER_TEMP/chezmoi/chezmoi" --override-data '\''{"ciSkipExternals":true}'\'' "\$@" --exclude=scripts ;;'* ]]
  last=$(printf '%s\n' "$output" | grep 'exec ' | tail -1)
  [[ "$last" == *"--override-data '{\"ciSkipExternals\":true}' \"\\\$@\""* ]]
  [[ "$output" == *'GITHUB_PATH'* ]]
}

@test "every script is rendered by the real chezmoi, without excluding scripts or downloading externals" {
  run step "render every script without running it"
  [[ "$output" == *'"$RUNNER_TEMP/chezmoi/chezmoi" apply --dry-run'* ]]
  [[ "$output" == *'ciSkipExternals'* ]]
  [[ "$output" != *'exclude'* ]]
}

@test "a Mac checks that chezmoi update pulls over SSH" {
  [ "$(yq -r '.jobs.install.steps[] | select(.name == "on macOS, chezmoi update pulls over SSH") | .if' "$CI_YML")" = "runner.os == 'macOS'" ]
  [[ "$(step "on macOS, chezmoi update pulls over SSH")" == *'ls-remote --get-url origin'* ]]
}

@test "the full route installs into a folder that does not exist yet" {
  run step "install into a folder that does not exist yet"
  [[ "$output" == *'install.sh --destination "$dest"'* ]]
  [[ "$output" == *'test -s'* ]]
  [ "$(yq -r '.jobs.install.steps[-1].name' "$CI_YML")" = "install into a folder that does not exist yet" ]
}

@test "every job has a timeout" {
  for f in "$REPO_ROOT"/.github/workflows/*.y*ml; do
    missing=$(yq -r '.jobs | to_entries[] | select(.value."timeout-minutes" == null) | .key' "$f")
    [ -z "$missing" ] || {
      echo "$f: $missing has no timeout-minutes" >&2
      return 1
    }
  done
}

@test "every action is pinned to a commit" {
  if grep -nE 'uses: [^ ]+@' "$REPO_ROOT"/.github/workflows/*.y*ml | grep -vE '@[0-9a-f]{40}( |$)'; then return 1; fi
}

@test "the Claude review runs only when asked" {
  f="$REPO_ROOT/.github/workflows/claude-code-review.yml"
  [ "$(yq -r '.on.pull_request.types | join(",")' "$f")" = labeled ]
  [[ "$(yq -r '.jobs."claude-review".if' "$f")" == *"'claude-review'"* ]]
}

@test "ci-ok depends on every job and runs whatever their result" {
  [ "$(yq -r '.jobs."ci-ok".if' "$CI_YML")" = "always()" ]
  jobs=$(yq -r '.jobs | keys | map(select(. != "ci-ok")) | sort | join(",")' "$CI_YML")
  [ "$(yq -r '.jobs."ci-ok".needs | sort | join(",")' "$CI_YML")" = "$jobs" ]
}

@test "only pull requests on main and the merge queue trigger CI, never a push" {
  [ "$(yq -r '.on.pull_request.branches | join(",")' "$CI_YML")" = main ]
  [ "$(yq -r '.on | has("merge_group")' "$CI_YML")" = true ]
  [ "$(yq -r '.on | has("push")' "$CI_YML")" = false ]
  [[ "$(yq -r '.jobs.changes.if' "$CI_YML")" == *'!github.event.pull_request.draft'* ]]
}

@test "a pull request runs the full install on Linux and macOS; the queue adds the Quick Start route" {
  [ "$(yq -r '.jobs.install.strategy.matrix.os | join(",")' "$CI_YML")" = "ubuntu-latest,macos-15" ]
  route=$(yq -r '.jobs.install.strategy.matrix.route' "$CI_YML")
  [[ "$route" == *"'pull_request' && '[\"full\"]'"* ]]
  # The full route uses the real chezmoi: the wrapper and the render step are Quick Start only.
  for s in "install chezmoi" "never run scripts or download externals" "render every script without running it"; do
    [ "$(yq -r ".jobs.install.steps[] | select(.name == \"$s\") | .if" "$CI_YML")" = "matrix.route == 'quick-start'" ]
  done
  [ "$(yq -r '.jobs.install.steps[] | select(.name == "install from the checkout") | .if' "$CI_YML")" = "matrix.route == 'full'" ]
  [[ "$route" == *'quick-start'* ]]
}

@test "the full install runs only on a schedule or by hand, with no exclusion" {
  f="$REPO_ROOT/.github/workflows/full-install.yml"
  [ "$(yq -r '.on | keys | sort | join(",")' "$f")" = "schedule,workflow_dispatch" ]
  if yq -r '.jobs[].steps[].run // ""' "$f" | grep -q -- '--exclude'; then return 1; fi
  if grep -q 'full-install' "$REPO_ROOT/.github/workflows/release.yaml"; then return 1; fi
}
