# vscode: VS Code

Visual Studio Code, the desktop editor, with its `code` command.

- macOS: the `visual-studio-code` Homebrew cask. Linux: the `code` package from
  Microsoft's apt repository; it needs sudo, so an apply without a terminal or
  sudo rights skips it and the next apply at a terminal installs it. Skipped
  when a `code` is already on PATH (your own install, a Remote-SSH session),
  and without a graphical session (no `DISPLAY` or `WAYLAND_DISPLAY`) or in a
  Codespace: there, `code_cli` gives `code-cli tunnel` instead. A failed
  `apt-get update` skips it until the next apply.
- Settings: the team `settings.json` (Catppuccin theme, Fira Code font) is
  created once and never overwritten, whether or not this module is selected:
  `~/Library/Application Support/Code/User/settings.json` on macOS,
  `~/.config/Code/User/settings.json` on Linux.
- Extensions: the Catppuccin theme, icons and direnv extensions, plus the
  Python ones with `python_dev`, install when `code` is on PATH. Every apply
  installs the missing ones, so a VS Code installed on a later apply gets them
  too. The list lives in `.chezmoidata/packages.yaml` under `vscode`.
- `code .` opens the current directory; `code --list-extensions` lists the
  installed extensions.
- Doctor: checks `code`; on Linux without a graphical session or in a
  Codespace, a missing `code` is a warning, not a problem.
