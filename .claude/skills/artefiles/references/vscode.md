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
- Remote-SSH with fish as the login shell: on the server, `config.fish` skips
  its interactive-only init while VS Code reads the environment
  (`VSCODE_RESOLVING_ENVIRONMENT` set), and `vscode_remote_check` times the
  probe VS Code runs (`$SHELL -ilc`, 10-second limit). If the connection still
  fails, run `vscode_remote_fix` on the machine that runs VS Code: it sets
  `"remote.SSH.useLocalServer": false` in its `settings.json` (the local server
  fails to connect to some fish hosts), switching a `true` in place, adding the
  key after the first `{` otherwise, and creating the file when there is none.
  Nothing sets it by default: without the local server each window opens its
  own SSH connection. Dev Containers: `"userEnvProbe": "loginInteractiveShell"`
  works once that probe passes.
- `code .` opens the current directory; `code --list-extensions` lists the
  installed extensions.
- Doctor: checks `code`; on Linux without a graphical session or in a
  Codespace, a missing `code` is a warning, not a problem.
  When the login shell is fish, a VS Code environment probe that does not
  answer within 10 seconds is a problem.
