# git_advanced: difftastic, git-cliff, git-lfs, git-extras, lazygit

| Tool | Use |
|---|---|
| difftastic (`difft`) | `git diff` shows structural diffs (git's `diff.external`); `git difftool` too. `git diff --no-ext-diff` gets the plain diff |
| lazygit | `lazygit`: terminal UI to stage hunks, commit, rebase, resolve conflicts. `?` lists the keys |
| git-cliff | `git cliff` writes a changelog from Conventional Commits; `git cliff --unreleased` previews the next release |
| git-lfs | `git lfs install` once per repo, then `git lfs track "*.bin"` |
| git-extras | extra git commands: `git summary`, `git effort`, `git undo`, `git delete-merged-branches` |

- The git config parts live in `~/.gitconfig` (managed) inside the
  `git_advanced` block; mergiraf (core) handles merges.
- Linux: git-extras is built from source only when a newer release exists.
- Doctor: checks each tool.
