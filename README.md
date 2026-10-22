# Artefiles

A ready-to-use terminal setup for macOS and Linux: Fish, Starship, modern CLI tools and a Catppuccin theme, installed with one command and **managed by [chezmoi](https://chezmoi.io/)** so you can edit, update and roll back every config ([commands](#using-chezmoi)).

![Terminal demo](docs/images/terminal-demo.png)

## Prerequisites

- macOS or Linux (x86_64 or arm64).
- A GitHub account: the installer logs `gh` in and reads your name and email from your profile.
- On macOS, your password once: Homebrew needs `sudo`.

## Install

```bash
sh -c "$(curl -fsLS https://raw.githubusercontent.com/artefactory/artefiles/main/install.sh)"
```

The [script](install.sh) does five things:
1. Checks your machine (system, tools, write access, network) and lists anything to fix before it changes anything.
2. Installs `gh` and signs you in to GitHub.
3. Installs chezmoi and shows a checklist of optional modules.
4. Saves the files it would change in a dated backup folder (under `.local/state/artefiles` in your home), then applies everything. `install.sh --restore <folder>` undoes the install from that folder.
5. Offers to make Fish your default shell and to star this repo. If you decline the shell change, the [cheatsheet](CHEATSHEET.md#default-shell) has the commands. With an `@artefact.com` email, it also says when your GitHub account is not yet in the artefactory organisation.

Then open a new terminal (type `fish` if you declined the shell change) and run `dotfiles_doctor` to check the install.

**Variants**

```bash
# Another release, or a branch such as main (the default is the latest release)
ARTEFILES_VERSION=main sh -c "$(curl -fsLS https://raw.githubusercontent.com/artefactory/artefiles/main/install.sh)"

# No browser (CI, a remote machine): sign in with a token
GH_TOKEN=<token> sh -c "$(curl -fsLS https://raw.githubusercontent.com/artefactory/artefiles/main/install.sh)"
```

In Codespaces, set this repo as your [dotfiles repository](https://github.com/settings/codespaces); it installs itself.

<details><summary>Install without the script</summary>

Install Homebrew (macOS) and `gh`, and log `gh` in first. This route has no checklist: chezmoi's own prompt asks for the modules. Then:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply \
  --branch "$(gh release view --repo artefactory/artefiles --json tagName --jq .tagName)" artefactory/artefiles
```
</details>

## What you get

Every install gives you the **Fish** shell (suggestions as you type) with the **Starship** prompt, **git**, **gh**, **uv** (Python), **fnm** (Node) and the FiraCode Nerd Font. The install checklist adds the rest as modules; these replace everyday commands:

| Instead of | Use | Module |
|---|---|---|
| `ls` / `cat` / `find` / `grep` | `eza` / `bat` / `fd` / `rg` | `shell_tools` |
| `cd` | `cd` ranked by use ([zoxide](https://github.com/ajeetdsouza/zoxide)) | `shell_tools` |
| `rm` / `du` / `ps` / `sed` | `rip` / `dust` / `procs` / `sd` | `cli_extras` |

**Keys:** `Tab` opens an fzf picker over every completion. `Ctrl+R` searches [Atuin](https://atuin.sh/) history, synced across machines (`atuin` module). `review` opens a terminal UI to review a diff, a branch or a pull request (`review` module). `git diff` uses difftastic (`git_advanced` module).

All modules (`[x]` marks the ones selected by default; without a terminal, chezmoi's own prompt lists them):

| Module | Description | Alternative to |
|--------|-------------|----------------|
| `editor` | Neovim: modal terminal editor with the team configuration (nvim) | — |
| `shell_tools` | Shell tools: bat, eza, fd, fzf, ripgrep, zoxide, direnv (modern cat, ls, find, search, cd) | — |
| `cli_extras` | Faster CLI replacements: dust, dysk, procs, sd, choose, hyperfine, bottom, rip2 | — |
| `rust` | Rust toolchain (rustup, cargo) to build Rust tools | — |
| `ghostty` | Ghostty terminal, preconfigured, plus Zellij (panes and tabs). Alternative to cmux: pick one | `cmux` |
| `cmux` | cmux: Ghostty-based macOS terminal, vertical tabs, agent notifications. Alternative to ghostty: pick one | `ghostty` |
| `git_advanced` | Extra git tools: difftastic (diffs), git-cliff (changelogs), git-lfs, git-extras, lazygit (TUI) | — |
| `atuin` | Atuin: searchable shell history, synced across machines (Ctrl+R) | — |
| `review` | tuicr: terminal UI to review a diff, a branch or a pull request (review command) | — |
| `python_dev` | Python tools: nbdime (notebook diffs), VS Code extensions | — |
| `data` | Data tools: DuckDB (SQL on CSV and Parquet files) and harlequin (SQL client in the terminal) | — |
| `pre_commit` | pre-commit: Git hook manager running linters and formatters on commit. Alternative to prek: pick one | `prek` |
| `prek` | prek: faster Rust drop-in for pre-commit, same config. Alternative to pre_commit: pick one | `pre_commit` |
| `gcloud` | Google Cloud SDK: the gcloud CLI to manage Google Cloud resources | — |
| `azure` | Azure CLI: the az command to manage Microsoft Azure resources | — |
| `containers` | Containers on macOS: Colima (runtime), the docker CLI with buildx, and lazydocker | — |
| `kubernetes` | Kubernetes: kubectl, and k9s to browse and manage clusters in the terminal | — |
| `terraform` | Terraform: infrastructure-as-code CLI to plan and apply cloud resources. Alternative to opentofu: pick one | `opentofu` |
| `opentofu` | OpenTofu: open-source fork of Terraform, same workflow (tofu). Alternative to terraform: pick one | `terraform` |

After installing: `atuin register` (or `atuin login`) turns on history sync, `gcloud init` sets up Google Cloud, and `az login` signs in to Azure. More commands and shortcuts are in the [cheatsheet](CHEATSHEET.md).

## Using chezmoi

chezmoi keeps a copy of every config in a source directory (`chezmoi source-path` prints it); `chezmoi apply` writes those files into your home directory.

| Task | Command |
|------|---------|
| See pending changes | `chezmoi status` / `chezmoi diff` |
| Edit a file | `chezmoi edit <path>` |
| Apply changes | `chezmoi apply` |
| Update from the repo | `chezmoi update` |
| Reset one file | `chezmoi apply --force <path>` |
| Change modules | `chezmoi init --prompt && chezmoi apply` |

## Make it yours

1. **Fork** this repo. On a new machine, clone your fork and run `./install.sh` inside it, or run `chezmoi init --apply <you>/artefiles`. Already installed? Point the existing source at your fork: `git -C "$(chezmoi source-path)" remote set-url origin <your fork URL>`.
2. **Edit** a config: `chezmoi edit ~/.config/fish/config.fish`, check it with `chezmoi diff`, apply it with `chezmoi apply`.
3. **Publish:** `chezmoi cd`, commit, push. Your other machines get it with `chezmoi update`.
4. **Follow upstream:** merges use [mergiraf](https://mergiraf.org/), which merges config files by structure.
   ```bash
   chezmoi cd
   git remote add upstream https://github.com/artefactory/artefiles.git   # once
   git pull upstream main
   chezmoi apply
   ```

## Update

`chezmoi update` moves to the newest [release](https://github.com/artefactory/artefiles/releases) and applies it; a clone on a branch (a fork, or `ARTEFILES_VERSION=<branch>`) pulls that branch instead. Each release lists what changed and what to do about breaking changes.

## More

[CHEATSHEET.md](CHEATSHEET.md) has the chezmoi commands, a guide per module, the sandbox (`./sandbox.sh`), the tests and how to remove everything. MIT licence.

Claude Code can help you install, update, debug and use these tools in any project once the artefiles skill is installed: `gh skill install artefactory/artefiles .claude/skills/artefiles/SKILL.md --allow-hidden-dirs --agent claude-code --scope user`.
