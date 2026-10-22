# pre_commit: git hook manager

Alternative to `prek`: pick one.

- Installs pre-commit (uv tool) and writes global git template hooks in
  `~/.git_template/hooks` (commit-msg, pre-commit, pre-push): every `git init`
  and clone runs the repo's `.pre-commit-config.yaml` without a manual install.
- `pre-commit run --all-files` checks the whole repo; `git commit --no-verify`
  skips the hooks once.
- Whether hooks run in a repository, and what to run if not: `scripts/hooks-status.sh`.
