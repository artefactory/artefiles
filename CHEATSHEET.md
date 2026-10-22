# Artefiles Cheatsheet

Quick reference for chezmoi and for testing artefiles. How to use each tool,
module by module, is in the [artefiles skill](.claude/skills/artefiles/SKILL.md)
references below; Claude Code reads the same files.

## Chezmoi

| Task | Command |
|------|---------|
| Status | `chezmoi status --exclude=scripts,externals` |
| Diff | `chezmoi diff` |
| Edit a file | `chezmoi edit ~/.config/fish/config.fish` |
| Apply changes | `chezmoi apply` |
| Update from repo | `chezmoi update` |
| Change modules | `chezmoi init --prompt && chezmoi apply` |
| Health check | `dotfiles_doctor` |

### Remove All Chezmoi-Managed Files (Danger)

Review first:
```bash
chezmoi managed -p absolute
```

Remove all managed files, then remove chezmoi state/source:
```bash
chezmoi managed -p absolute -0 | xargs -0 chezmoi destroy --force
chezmoi purge --force
```

## Default shell

If you declined the installer's offer to make fish your default shell:

```bash
# macOS
command -v fish | sudo tee -a /etc/shells
chsh -s "$(command -v fish)"
# Linux
chsh -s "$(command -v fish)"
```

Log out and back in, and fully quit and reopen your IDE, for the change to show.

## Tools by module

| Module | Tools | Guide |
|---|---|---|
| every install | fish, starship, git, gh, mergiraf, uv, fnm | [core](.claude/skills/artefiles/references/core.md) |
| `editor` | Neovim: modal terminal editor with the team configuration (nvim) | [editor](.claude/skills/artefiles/references/editor.md) |
| `shell_tools` | Shell tools: bat, eza, fd, fzf, ripgrep, zoxide, direnv (modern cat, ls, find, search, cd) | [shell_tools](.claude/skills/artefiles/references/shell_tools.md) |
| `cli_extras` | Faster CLI replacements: dust, dysk, procs, sd, choose, hyperfine, bottom, rip2 | [cli_extras](.claude/skills/artefiles/references/cli_extras.md) |
| `rust` | Rust toolchain (rustup, cargo) to build Rust tools | [rust](.claude/skills/artefiles/references/rust.md) |
| `ghostty` | Ghostty terminal, preconfigured, plus Zellij (panes and tabs). Alternative to cmux: pick one | [ghostty](.claude/skills/artefiles/references/ghostty.md) |
| `cmux` | cmux: Ghostty-based macOS terminal, vertical tabs, agent notifications. Alternative to ghostty: pick one | [cmux](.claude/skills/artefiles/references/cmux.md) |
| `git_advanced` | Extra git tools: difftastic (diffs), git-cliff (changelogs), git-lfs, git-extras, lazygit (TUI) | [git_advanced](.claude/skills/artefiles/references/git_advanced.md) |
| `atuin` | Atuin: searchable shell history, synced across machines (Ctrl+R) | [atuin](.claude/skills/artefiles/references/atuin.md) |
| `review` | tuicr: terminal UI to review a diff, a branch or a pull request (review command) | [review](.claude/skills/artefiles/references/review.md) |
| `python_dev` | Python tools: nbdime (notebook diffs), VS Code extensions | [python_dev](.claude/skills/artefiles/references/python_dev.md) |
| `data` | Data tools: DuckDB (SQL on CSV and Parquet files) and harlequin (SQL client in the terminal) | [data](.claude/skills/artefiles/references/data.md) |
| `pre_commit` | pre-commit: Git hook manager running linters and formatters on commit. Alternative to prek: pick one | [pre_commit](.claude/skills/artefiles/references/pre_commit.md) |
| `prek` | prek: faster Rust drop-in for pre-commit, same config. Alternative to pre_commit: pick one | [prek](.claude/skills/artefiles/references/prek.md) |
| `gcloud` | Google Cloud SDK: the gcloud CLI to manage Google Cloud resources | [gcloud](.claude/skills/artefiles/references/gcloud.md) |
| `azure` | Azure CLI: the az command to manage Microsoft Azure resources | [azure](.claude/skills/artefiles/references/azure.md) |
| `containers` | Containers on macOS: Colima (runtime), the docker CLI with buildx, and lazydocker | [containers](.claude/skills/artefiles/references/containers.md) |
| `kubernetes` | Kubernetes: kubectl, and k9s to browse and manage clusters in the terminal | [kubernetes](.claude/skills/artefiles/references/kubernetes.md) |
| `terraform` | Terraform: infrastructure-as-code CLI to plan and apply cloud resources. Alternative to opentofu: pick one | [terraform](.claude/skills/artefiles/references/terraform.md) |
| `opentofu` | OpenTofu: open-source fork of Terraform, same workflow (tofu). Alternative to terraform: pick one | [opentofu](.claude/skills/artefiles/references/opentofu.md) |

## Testing & Development

### Testing in a Temporary Environment

| Task | Command |
|------|---------|
| Create test directory | `mkdir -p /tmp/chezmoi-test` |
| Test with dry run | `CHEZMOI_CONFIG=/path/to/tmp-config.yaml XDG_CONFIG_HOME=/tmp/test-xdg chezmoi apply --dry-run --verbose` |
| Clean up test env | `rm -rf /tmp/chezmoi-test /tmp/test-xdg` |

Example test config:
```yaml
data:
  name: "test-user"
  email: "test@example.com"
sourceDir: /path/to/artefiles/repo
destDir: /tmp/chezmoi-test
```

### Tests and CI

| What | Where | Command |
|------|-------|---------|
| Unit tests (local only) | `tests/*.bats` | `bats tests/` |
| One file | `tests/<name>.bats` | `bats tests/preflight.bats` |
| Full install, packages included, on macOS + Linux | `.github/workflows/ci.yml` | every ready pull request on `main` |
| Same, plus the Quick Start route | `.github/workflows/ci.yml` | the merge queue ("Merge when ready") |
| Full install with packages | `.github/workflows/full-install.yml` | weekly, or `gh workflow run full-install.yml --ref <branch>` |
| Claude review | `.github/workflows/claude-code-review.yml` | add the `claude-review` label |

CI runs `install.sh` on fresh runners, then `.github/scripts/verify-install.sh` checks the source commit, the stored answers, that the core files are managed and written, `chezmoi verify` and `chezmoi doctor`. On pull requests the install is full, packages included; the Quick Start route in the merge queue runs no scripts and downloads no externals. The weekly full install on `main` catches a download that breaks between pull requests. Draft pull requests and pull requests stacked on another branch run nothing. `ci-ok` is the one check the merge queue requires.

### Try it in a sandbox

To simulate a new user's install without touching your own machine:

```bash
./sandbox.sh                                   # the whole install, interactively, then a shell in the sandbox
./sandbox.sh --gh-token                        # same, lending your gh token so GitHub answers for real
./sandbox.sh --modules atuin,editor            # skip the install and prompts, seed these modules
./sandbox.sh --modules editor --command 'ls -a "$HOME/.config"'
./sandbox.sh --clean                           # remove the leftovers of earlier runs
```

By default it runs the real `install.sh` inside a temporary home: the gh check and login, chezmoi, its prompts and the files applied from your checkout. Every side effect on your machine is stubbed and listed at the end as `(sandbox) would run: ...`: brew, downloads, the gh login, `sudo`, `chsh`, and chezmoi's scripts and externals, so nothing is installed and your real configuration is never read or written. Without `--gh-token` (or `GH_TOKEN`), `gh` is logged out as for a brand-new user, and the login is only simulated. `--keep` leaves the sandbox on disk and `--clean` removes the leftovers of earlier runs, including after a crash; a normal exit or Ctrl-C removes it by itself.

After the install it lists the scripts chezmoi would run, and on Linux the externals it would download (rendered from the real template), so module installs can be reviewed without running them. What it does not exercise: the Quick Start clone path (the sandbox always has the checkout) and a `gh` that is not installed yet. `curl`, `wget`, `sudo` and `chsh` are stubbed (the install's header-only `curl` network check still reaches GitHub) and no tool is installed in the sandbox, so its shell can print missing-command messages a real user would not see. For a full Linux install in a container, run `./docker-test.sh`.

The install's own steps are shown too: the module checklist (arrows and space to pick modules, then Enter on the Submit row), and the star offer, which is answered without a token because the sandbox only logs the star it would send.
