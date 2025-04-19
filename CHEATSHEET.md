# Artefiles Cheatsheet

This cheatsheet provides quick reference for common commands and workflows. For detailed documentation, see the [README.md](README.md).

## Table of Contents

- [Environment Setup](#environment-setup)
- [Core Tools](#core-tools)
- [Terminal & Shell](#terminal--shell)
- [Git & Version Control](#git--version-control)
- [Remote Server Operations](#remote-server-operations)
- [Python Development](#python-development)
- [System Health & Diagnostics](#system-health--diagnostics)
- [WezTerm Terminal](#wezterm-terminal)
- [Testing & Development](#testing--development)

## Environment Setup

### Configuration Structure

```
~/.config/
  ├── fish/            # Shell configuration
  │   ├── config.fish  # Main shell configuration
  │   ├── aliases.fish # Shell aliases and functions
  │   └── functions/   # Custom fish functions
  ├── nvim/            # Editor configuration
  ├── direnv/          # Environment management
  ├── bat/             # Syntax highlighting
  └── starship.toml    # Prompt configuration

~/.ssh/config          # SSH configuration
~/.wezterm.lua        # Terminal configuration
~/.gitconfig          # Git configuration
```

### Core Tools

| Tool | Description | Usage |
|------|-------------|-------|
| [Fish Shell](https://fishshell.com/) | Modern shell | Intelligent autosuggestions and syntax highlighting |
| [Starship](https://starship.rs/) | Shell prompt | Fast, informative prompt with Git integration |
| [Neovim](https://neovim.io/) | Text editor | Modern Vim with better defaults |
| [bat](https://github.com/sharkdp/bat) | Cat replacement | Syntax highlighting for file viewing |
| [eza](https://github.com/eza-community/eza) | ls replacement | Improved file listing with Git integration |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | cd replacement | Smart directory navigation |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | Interactive filtering for files and history |
| [uv](https://github.com/astral-sh/uv) | Python package manager | Fast package installation and environment management |
| [direnv](https://direnv.net/) | Environment manager | Per-directory environment variables |
| [atuin](https://github.com/atuinsh/atuin) | Shell history | Searchable, syncable shell history |

### Post-Installation Steps

1. Shell History Sync (atuin):
   ```bash
   atuin register     # Create new account
   atuin login        # Login to existing account
   atuin import auto  # Import existing shell history
   ```

2. Git Configuration:
   - Edit configuration: `chezmoi edit ~/.gitconfig`
   - Set commit signing: `git config --global commit.gpgsign true`
   - Configure user info: `git config --global user.name "Your Name"`

3. Cloud Tools:
   - Google Cloud SDK: `gcloud init` and `gcloud auth login`
   - Set default project: `gcloud config set project PROJECT_ID`
   - Install components: `gcloud components install kubectl`

## Terminal & Shell

| Task | Command |
|------|---------|
| List files with details | `ll` (alias for `eza -lh --group-directories-first`) |
| View file with syntax highlighting | `cat file.py` (uses `bat`) |
| Change directory with history | `cd` (uses `zoxide` for smart navigation) |
| Find files by name | `fd pattern` |
| Fuzzy find files | `fzf` |
| Watch file contents | `watch-file logfile.txt` |
| Run commands in background | `command args | run-and-watch output.log` |
| Search command history | `Ctrl+R` (uses `atuin`) |
| Activate Python environment | `direnv allow` (in directory with `.envrc`) |

### Basic Navigation & File Operations

| Task | Command | Description |
|------|---------|-------------|
| List files | `ls` | Group directories first |
| List details | `ll` | Long format with human sizes |
| List hidden | `la` | Include hidden files |
| Tree view | `lt` | Show directory tree |
| View file | `cat file` | Syntax highlighting (uses bat) |
| Find files | `find pattern` | Smart find (uses fd) |
| Change directory | `cd` | Smart navigation (uses zoxide) |

### Utility Functions

| Function | Usage | Description |
|----------|-------|-------------|
| `watch-file` | `watch-file <file> [language] [--bat-args "..."]` | Watch file with live syntax highlighting |
| | `watch-file log.txt json` | Force JSON highlighting |
| | `watch-file data.txt --bat-args "--plain"` | Custom bat display options |
| `launch` | `launch <command> [args...] [logfile]` | Run command in background |
| | `launch rsync -avz src/ dest/ sync.log` | Background file sync |
| | `launch jupyter lab notebook.log` | Start Jupyter in background |

## Git & Version Control

| Task | Command |
|------|---------|
| Status | `gs` (alias for `git status`) |
| Add files | `ga` (alias for `git add`) |
| Commit | `gc` (alias for `git commit`) |
| Push | `gp` (alias for `git push`) |
| Pull | `gl` (alias for `git pull`) |
| Visual diff | `git diff` (uses `difft` or `nbdime` for notebooks) |
| Pretty log | `glog` |
| Create PR | `ghpr` (alias for `gh pr create`) |
| View PR | `ghprv` (alias for `gh pr view`) |
| List PRs | `ghprl` (alias for `gh pr list`) |

### Git Shortcuts

| Alias | Command | Description |
|-------|---------|-------------|
| `g` | `git` | Git shorthand |
| `gs` | `git status` | Repository status |
| `ga` | `git add` | Stage changes |
| `gc` | `git commit` | Commit changes |
| `gp` | `git push` | Push commits |
| `gl` | `git pull` | Pull changes |
| `gd` | `git diff` | Show changes |
| `gco` | `git checkout` | Switch branches |
| `gb` | `git branch` | Manage branches |
| `glog` | Pretty git log | Colored graph log |

## Remote Server Operations

### Remote Command Execution

| Feature | Description | Example |
|---------|-------------|---------|
| Basic execution | Run command on remote server | `remote_exec server "ls -la"` |
| Tab completion | Complete from SSH config | `remote_exec set<TAB>` |
| Host aliases | Use SSH config aliases | `remote_exec dev` |
| Command completion | Complete from remote PATH | `remote_exec server pyth<TAB>` |
| Terminal handling | Proper TTY allocation | `remote_exec server "htop"` |
| Multi-word commands | Quote complex commands | `remote_exec server "ps aux | grep python"` |

Completion Features:
- SSH host completion from ~/.ssh/config
- Username and hostname completion
- Remote command completion from PATH
- Argument completion for common commands

### SSH Configuration

| Task | Config Location | Example |
|------|----------------|---------|
| Add server | `~/.ssh/config` | Use `chezmoi edit ~/.ssh/config` |
| Update known hosts | `~/.ssh/known_hosts` | Automatic during first connection |
| Test connection | Use remote_exec | `remote_exec server "echo test"` |

SSH Configuration Template:
```
Host myserver
    HostName myserver.example.com
    User myusername
    ForwardAgent yes
    ServerAliveInterval 60
```

### Common Remote Workflows

| Task | Command | Notes |
|------|---------|-------|
| Check server status | `remote_exec server "uptime"` | Shows load average |
| Monitor processes | `remote_exec server "htop"` | Interactive process viewer |
| Check disk space | `remote_exec server "df -h"` | Human-readable sizes |
| View logs | `remote_exec server "tail -f /var/log/syslog"` | Live log monitoring |
| Install package | `remote_exec server "uv pip install package"` | Uses uv on remote |
| Run background job | `remote_exec server "nohup command &"` | Continues after disconnect |

## Python Development

| Task | Command |
|------|---------|
| Create new virtual environment | `uv venv` |
| Create project with automatic env | `mkdir project && cd project && echo 'layout uv' > .envrc && direnv allow` |
| Install packages | `uv pip install package1 package2` |
| Install from requirements | `uv pip install -r requirements.txt` |
| Run script in isolated env | `uv run python script.py` |
| Launch Jupyter | `jupyter lab` |

## System Health & Diagnostics

### Health Check Commands

The `dotfiles_doctor` command performs comprehensive environment checks:

1. Tool Status Checks:
   | Category | Tools Checked |
   |----------|---------------|
   | Core | chezmoi, fish, starship, wezterm, direnv |
   | Editors | neovim, vscode |
   | CLI Tools | bat, eza, fd, fzf, zoxide, atuin |
   | Git Tools | git, git-lfs, github-cli, difftastic, git-cliff, git-extras, pre-commit |
   | Development | gcloud, uv |
   | Platform | brew (macOS only) |

2. Font Status:
   | Check | Description |
   |-------|-------------|
   | Font Installation | Verifies Nerd Font presence |
   | Font Cache | Updates font cache (Linux) |
   | Directory Access | Checks font directories |

3. Environment Status:
   | Check | Success Criteria |
   |-------|-----------------|
   | Terminal Integration | WezTerm detection |
   | Git Configuration | user.name and user.email set |
   | GitHub Auth | CLI authentication active |
   | Shell History | Atuin sync enabled |

4. Version Information:
   - Shows installed version for each tool
   - Handles different version formats
   - Indicates missing tools

Output Format:
```
RESULT     CHECK                      MESSAGE
ok         tool-name                  version-info
warning    missing-tool               not found
info       optional-feature           status
```

### Tool-Specific Health Checks

| Tool | Health Check | Fix Command |
|------|-------------|-------------|
| Fish Shell | `fish --version` | Re-run installer |
| Neovim | `nvim --version` | Re-run installer |
| Git | `git config --list` | Edit ~/.gitconfig |
| Python (uv) | `uv --version` | Re-run installer |
| Direnv | Test .envrc loading | Check direnv hook in config.fish |

### Font Management

| Task | Command | Description |
|------|---------|-------------|
| Install font | `install_nerd_font <font-name>` | Install Nerd Font automatically |
| Check installation | `is_nerd_font_installed <font-name>` | Test if font is installed |
| List available fonts | `install_nerd_font` (no arguments) | Show usage and font info |
| Show fonts | `fc-list` (Linux) or `system_profiler SPFontsDataType` (macOS) | List installed fonts |

Common Font Names:
- `FiraCode` - Default coding font
- `JetBrainsMono` - Clear, distinctive font
- `Hack` - Clean monospace font
- `SourceCodePro` - Adobe's coding font
- `Monaspace` - GitHub's new font family

Features:
- Automatic version detection
- OS-specific installation paths
- Fallback version support
- Progress indicators
- Font cache updating (Linux)

## WezTerm Terminal

### Basic Navigation

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+N` | New window |
| `Ctrl+Shift+LeftArrow/RightArrow` | Switch tabs |
| `Ctrl+Shift+-` | Split pane horizontally |
| `Ctrl+Shift+\` | Split pane vertically |
| `Alt+Arrow` | Navigate between panes |

### SSH Integration

| Task | Command | Description |
|------|---------|-------------|
| Connect SSH | `wezterm ssh user@host` | Open new SSH connection |
| Multiplexed SSH | `wezterm connect SSHMUX:host` | Open multiplexed SSH session |
| SSH with Config | `wezterm connect user@host` | Use SSH config settings |

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
