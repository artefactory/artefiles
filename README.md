# Artefiles

A cross-platform dotfiles template that provides a **default and sane configuration for a modern development environment**. Managed with [chezmoi](https://chezmoi.io/), these dotfiles deliver a consistent, opinionated setup focused on productivity and modern tooling.

## Philosophy

This repository is designed to give you a **batteries-included development environment** that:
- Uses **Fish Shell** for intelligent autosuggestions and superior user experience
- Leverages **modern Rust-based Unix tools** (eza, bat, fd, rg) for better performance and UX
- Provides consistent configuration across macOS and Linux platforms
- Offers a **modular architecture**: a core layer is always installed, and additional modules are opt-in

![Terminal Screenshot](docs/images/terminal-demo.png)
*Modern terminal setup with Fish shell, Starship prompt, and Rust-based tools*

## Quick Start

```bash
sh -c "$(curl -fsLS https://raw.githubusercontent.com/artefactory/artefiles/main/install.sh)"
```

This is the recommended path. The script:
1. Installs [GitHub CLI](https://cli.github.com/) if not already present
2. Authenticates you with GitHub (interactive browser flow, or reads a token from the environment — see below)
3. Installs [chezmoi](https://chezmoi.io/) and runs `chezmoi init --apply`

> **Why not `curl get.chezmoi.io | sh ... init --apply` directly?**
> `.chezmoi.toml.tmpl` calls `gh api user` at init time to pre-populate your name and email.
> GitHub CLI must be installed and authenticated *before* `chezmoi init` runs.
> `install.sh` enforces that order; the chezmoi-direct path does not.

### Non-interactive Environments (Codespaces / CI)

For headless environments where a browser login is not possible, set a GitHub token before running the script:

```bash
export GH_TOKEN=ghp_your_token_here
sh -c "$(curl -fsLS https://raw.githubusercontent.com/artefactory/artefiles/main/install.sh)"
```

`GITHUB_TOKEN` is also accepted and is set automatically in GitHub Actions. In Codespaces the token is already in the environment, so no extra configuration is needed beyond adding this repository as your dotfiles source.

### GitHub Codespaces

These dotfiles can automatically bootstrap your GitHub Codespace environment:

1. Add this repository as your dotfiles in your [GitHub Codespaces settings](https://github.com/settings/codespaces)
2. Create a new codespace — it will automatically apply these dotfiles using `install.sh`

Learn more about Codespaces dotfiles in the [official documentation](https://docs.github.com/en/codespaces/customizing-your-codespace/personalizing-github-codespaces-for-your-account#dotfiles).

### Manual / Advanced Installation

If you prefer to manage prerequisites yourself before running chezmoi directly:

1. Install [Homebrew](https://brew.sh/) (macOS):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install [GitHub CLI](https://github.com/cli/cli#installation) using your preferred method for your platform.

3. Authenticate with GitHub CLI following the [official instructions](https://cli.github.com/manual/gh_auth_login), or set `GH_TOKEN` in your environment.

4. Install these dotfiles directly with chezmoi:
   ```bash
   sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply artefactory/artefiles
   ```

## Modular Architecture

Artefiles uses a **core + opt-in modules** design. During `chezmoi init`, you select which modules to enable via an interactive prompt.

### Core (always installed)

Fish, Starship, Git, bat, eza, fd, fzf, ripgrep, zoxide, rip2, dust, bottom, direnv, uv, Rust, FiraCode Nerd Font, VS Code.

### Optional Modules

| Module | Contents | Description |
|--------|----------|-------------|
| `editor` | Neovim | Terminal editor with nvim aliases |
| `terminal` | Ghostty | Modern GPU-accelerated terminal emulator |
| `git_advanced` | jj, mergiraf, difftastic, git-cliff, git-lfs, git-extras | Advanced version control tooling |
| `atuin` | Atuin | Shell history sync across machines |
| `python_dev` | nbdime, pre-commit (via uv) | Python/Jupyter development tools |
| `gcloud` | Google Cloud SDK | Google Cloud CLI (cask on darwin, manual install on linux) |
| `colima` | Colima | Container runtime (darwin only) |
| `multiplexer` | Zellij | Terminal multiplexer |
| `aerospace` | AeroSpace | Tiling window manager (darwin only) |
| `onepassword` | 1Password, 1Password CLI | Password manager (darwin only) |

### Changing Modules

Re-run `chezmoi init` to update your module selection, then `chezmoi apply`.

## What's Included

### Core Features

- 🐟 **[Fish Shell](https://fishshell.com/)** - A smart command-line shell that suggests commands as you type and has better tab completion than traditional shells
- ⚡ **[Starship](https://starship.rs/)** - A customizable terminal prompt that shows useful information like git status, programming language versions, and execution time
- 🔍 **Modern CLI Tools** - Faster, more user-friendly replacements for traditional Unix commands:
  - `bat` - Enhanced version of `cat` with syntax highlighting and line numbers
  - `eza` - Better `ls` with colors, git status, and tree view
  - `fd` - Faster, easier-to-use alternative to `find` for searching files
  - `fzf` - Fuzzy finder for quickly searching through files and command history. Also rebound onto Tab as the completion picker: every fish completion — commands, subcommands, flags, and flag values — opens in fzf instead of fish's native pager, with live re-filtering as you type
  - `rip` - Safe `rm` replacement with a recoverable graveyard
  - `ripgrep` - Lightning-fast text search across files
- 🌟 **[Catppuccin](https://github.com/catppuccin/catppuccin)** - A beautiful, consistent color theme applied across all tools for a cohesive look

### Optional Module Highlights

- 📝 **[Neovim](https://neovim.io/)** (`editor`) - A powerful text editor with syntax highlighting, plugins, and modern features
- 🔄 **Advanced Git** (`git_advanced`) - [Jujutsu](https://github.com/jj-vcs/jj), [mergiraf](https://mergiraf.org/), [difftastic](https://github.com/Wilfred/difftastic), [git-cliff](https://git-cliff.org/), [Git LFS](https://git-lfs.com/), [git-extras](https://github.com/tj/git-extras) (~80 helper subcommands like `git summary`, `git undo`, `git ignore`, `git wip`), and [tuicr](https://tuicr.dev/) - a vim-keybinding code review TUI (works with both git and jj), wired up as the `review` fish command: `review` (uncommitted changes), `review file <path>`, `review branch [base]`, `review commit [rev]`, `review pr <n>`, `review list`, `review comments` — `review <Tab>` opens the fzf picker with a description for each
- 📊 **Jupyter Notebook Support** (`python_dev`) - nbdime and pre-commit via uv
- 🐋 **Container Development** (`cloud`) - [Colima](https://github.com/abiosoft/colima) for running Docker containers on macOS without Docker Desktop
- ⏰ **Shell History** (`atuin`) - [Atuin](https://atuin.sh/) syncs your command history across machines with powerful search
- 📁 **Smart Navigation** - [Zoxide](https://github.com/ajeetdsouza/zoxide) learns your most-used directories for instant navigation

## What Files Will Be Created/Modified

⚠️ **Important**: These dotfiles do NOT modify your shell startup files (.profile, .zprofile, etc.). To benefit from the Fish shell configuration, you must manually change your default shell (see [Post-Installation Steps](#post-installation-steps)).

### Git Configuration
- `~/.gitconfig` - Git configuration with modern defaults ([Git Documentation](https://git-scm.com/docs/git-config))
- `~/.gitattributes_global` - Global attributes for merge drivers and file handling

### Terminal Configuration
- `~/.config/ghostty/config` - Ghostty terminal configuration ([Ghostty Documentation](https://ghostty.org/)) (requires `terminal` module)

### VS Code Configuration
- `~/.config/Code/User/settings.json` *(Linux)* — Default VS Code settings (Catppuccin theme, FiraCode font, fish terminal, Ruff formatter). Created on first apply only; your edits are never overwritten on `chezmoi update`.
- `~/Library/Application Support/Code/User/settings.json` *(macOS)* — Same default VS Code settings as the Linux path above. Created on first apply only; never overwritten on `chezmoi update`.

### Fish Shell Configuration ([Fish Shell Documentation](https://fishshell.com/docs/current/))
- `~/.config/fish/config.fish` - Main Fish shell configuration
- `~/.config/fish/aliases.fish` - Shell aliases and functions
- `~/.config/fish/conf.d/artefiles_abbrs.fish` - Fish abbreviations managed by chezmoi
- `~/.config/fish/fish_plugins` - Fish plugin list
- `~/.config/fish/functions/fish_title.fish` - Terminal title function
- `~/.config/fish/functions/smart_bat.fish` - Enhanced bat function (VSCode-aware)
- `~/.config/fish/functions/dotfiles_doctor.fish` - Health check function
- `~/.config/fish/functions/fuzzy_complete.fish` - Tab completion picker backed by fzf, plus its helpers (`_fuzzy_complete_render.fish`, `_fuzzy_complete_insert.fish`, `__cached_init.fish`)
- `~/.config/fish/completions/cd.fish` - Zoxide-ranked `cd` completions, with an unambiguous-jump shortcut that skips the picker
- `~/.config/fish/conf.d/direnv.fish` - Defers direnv's shell hook to the first prompt instead of every startup
- `~/.config/fish/functions/review.fish` and `~/.config/fish/completions/review.fish` - The `review` command wrapping tuicr (requires `git_advanced` module)
- `~/.config/fish/functions/__atuin_fzf_search.fish` and `~/.config/fish/scripts/atuin_fzf_list.sh` - Atuin history rendered through fzf, bound to Ctrl+R/Alt+R/Alt+F (requires `atuin` module and `perl`, present by default on macOS and mainstream Linux distros)

### Shell Prompt
- `~/.config/starship.toml` - Shell prompt configuration ([Starship Documentation](https://starship.rs/))

#### Customizing Starship
- [Configuration guide](https://starship.rs/config/) - module reference and syntax
- [Presets gallery](https://starship.rs/presets/) - ready-made prompt styles
- [Catppuccin theme](https://github.com/catppuccin/starship) - palette currently in use

### Development Tools
- `~/.config/bat/config` - Syntax highlighter configuration ([Bat Documentation](https://github.com/sharkdp/bat))
- `~/.config/direnv/direnvrc` - Environment management ([Direnv Documentation](https://direnv.net/))
- `~/.config/uv/uv.toml` - Python package manager configuration ([uv Documentation](https://docs.astral.sh/uv/))
- `~/.config/atuin/config.toml` - Shell history sync ([Atuin Documentation](https://atuin.sh/)) (requires `atuin` module)
- `~/.config/tuicr/config.toml` - Code review TUI configuration ([tuicr Documentation](https://tuicr.dev/)) (requires `git_advanced` module)
- `~/.config/nvim/init.lua` - Neovim editor configuration ([Neovim Documentation](https://neovim.io/doc/)) (requires `editor` module)

### macOS Window Manager
- `~/.config/aerospace/aerospace.toml` *(macOS)* - AeroSpace window manager ([AeroSpace Documentation](https://nikitabobko.github.io/AeroSpace/)) (requires `macos_desktop` module)

## Prerequisites

- A GitHub account (for git and GitHub-related features)
  - For non-interactive environments, set `GH_TOKEN` or `GITHUB_TOKEN` before installation
- SSH keys added to your GitHub account ([instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent))

After installation, you will need to change your default shell to Fish to get the full experience — see [Post-Installation Steps](#post-installation-steps).

## Common Tasks

| Task | Command |
|------|---------|
| Update dotfiles | `chezmoi update` |
| Edit config | `chezmoi edit <path>` |
| Health check | `dotfiles_doctor` |
| New Python project | `mkdir project && cd project && echo 'layout uv' > .envrc && direnv allow` |

## Chezmoi Basics

Chezmoi is the manager for these dotfiles. Main docs: https://www.chezmoi.io/user-guide/command-overview/

| Task | Command |
|------|---------|
| See pending changes | `chezmoi status` |
| Inspect diffs | `chezmoi diff` |
| Edit a file | `chezmoi edit ~/.config/fish/config.fish` |
| Apply changes | `chezmoi apply` |
| Update from repo | `chezmoi update` |

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

## Configuration Structure

```
~/.config/
  ├── aerospace/       # macOS window manager (macos_desktop module)
  ├── atuin/           # Shell history sync (atuin module)
  ├── bat/             # Syntax highlighting
  ├── direnv/          # Environment management
  ├── fish/            # Shell configuration
  │   ├── config.fish  # Main shell configuration
  │   ├── aliases.fish # Shell aliases and functions
  │   └── functions/   # Custom fish functions
  ├── ghostty/         # Terminal emulator (terminal module)
  ├── nvim/            # Editor configuration (editor module)
  ├── uv/              # Python package manager
  └── starship.toml    # Prompt configuration

~/.ssh/config          # SSH configuration
~/.gitconfig           # Git configuration
```

## Post-Installation Steps

### 1. Change Default Shell to Fish (Required for Full Experience)

`install.sh` does **not** change your default shell — this requires `sudo` and is a deliberate user choice.

Set Fish as your default login shell after installation:

**macOS:**
```bash
command -v fish | sudo tee -a /etc/shells
chsh -s $(brew --prefix)/bin/fish
```

**Linux:**
```bash
chsh -s $(which fish)
```

You may need to log out and back in for the shell change to take effect. If you're using VS Code or another IDE, fully quit and reopen it so the Fish profile shows up in the terminal list.

### 2. Set up shell history sync

```bash
atuin register  # New account
atuin login     # Existing account
```

### 3. Initialize cloud tools (if needed)

```bash
gcloud init  # Set up Google Cloud SDK
```

### 4. Restart your terminal or IDE

Restart your terminal (or fully quit and reopen your IDE if using VS Code, Cursor, etc.) for all changes to take effect.

## Need Help?

- Run `dotfiles_doctor` to check your installation
- See `chezmoi help` for dotfiles management
- Check the [CHEATSHEET.md](CHEATSHEET.md) for more commands
- Reset a file: `chezmoi apply --force <path>`

## Detailed Documentation

- [CHEATSHEET.md](CHEATSHEET.md) - Common commands and shortcuts
- [CHANGELOG.md](CHANGELOG.md) - Version history and updates

## License

MIT
