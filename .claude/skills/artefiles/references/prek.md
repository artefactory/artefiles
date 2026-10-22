# prek: faster pre-commit

Alternative to `pre_commit`: pick one. Same `.pre-commit-config.yaml`.

- Installs prek (uv tool) and writes the global git template hooks in
  `~/.git_template/hooks` (commit-msg, pre-commit, pre-push).
- `prek run --all-files` checks the whole repo. Whether hooks run in a
  repository, and what to run if not: `scripts/hooks-status.sh`.
