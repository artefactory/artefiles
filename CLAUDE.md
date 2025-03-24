# CLAUDE.md - Coding Agent Guidelines

## Repository Overview

This is a dotfiles template repository managed with [chezmoi](https://chezmoi.io/).

## Environment Assumptions

- macOS: Local machine with GUI applications support
- Linux: Almost always a remote server without GUI environment
  - Do not install GUI applications on Linux
  - Focus on CLI tools and terminal utilities only
  - Avoid root/sudo requirements when possible

## Commands

- Install/initialize: `./install.sh`
- Apply changes: `chezmoi apply`
- Add file: `chezmoi add ~/.file`
- Edit file: `chezmoi edit ~/.file`
- Update repository: `chezmoi update`

## Installation Procedures

### Adding New Tools

- **Linux Installation**:
  - Use installation scripts provided by developers OR
  - Install from GitHub binaries
  - Avoid adding system-wide dependencies with sudo/root requirements

- **macOS Installation**:
  - Add entry in `.chezmoidata/packages.yaml` file
  - This file is read and executed by `.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl`

- **Documentation**:
  - Always update the README.md when a new tool is installed
  - Add description and usage examples to the appropriate section

## Code Style

- Shell scripts: Follow POSIX sh compatibility
- Use 2-space indentation
- Add comments for non-obvious code sections
- Prefer parameter substitution for variable handling: `${var:-default}`
- Error handling: Set `set -eu` in shell scripts
- Naming: Use snake_case for variables and functions

## Best Practices

- Keep scripts idempotent
- Validate commands exist before using them
- Document environment assumptions
- Quote all variables: `"${var}"`
- Avoid hardcoded paths when possible

## Template Customization

- Chezmoi template delimiters can be customized in each file
- Add a comment at the beginning of the file to define custom delimiters
- Use language-appropriate comment syntax for better readability and syntax highlighting
- Format: `<comment char> chezmoi:template:left-delimiter="<comment char> [[" right-delimiter="]] <comment char>"`
- Examples for different languages:

  ```sh
  # Shell scripts (.sh, .profile, .zprofile)
  # chezmoi:template:left-delimiter="# [[" right-delimiter="]] #"
  ```

  ```lua
  -- Lua files (.lua)
  -- chezmoi:template:left-delimiter="-- [[" right-delimiter="]] --"
  ```

  ```toml
  # TOML files (.toml)
  # chezmoi:template:left-delimiter="# [[" right-delimiter="]] #"
  ```

- This replaces the default `{{` and `}}` with more language-appropriate delimiters
- Custom delimiters improve syntax highlighting and make templates easier to read
- The custom delimiters are then used throughout the file for template logic and variable insertion
