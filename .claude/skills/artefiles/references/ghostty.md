# ghostty: Ghostty terminal

- Ghostty: the macOS cask; on Linux the AppImage as `~/.local/bin/ghostty`,
  downloaded only in a graphical session (`DISPLAY` or `WAYLAND_DISPLAY` set,
  not a Codespace), as for VS Code. An apply over SSH skips it.
- Config `~/.config/ghostty/config`, managed on every OS: Catppuccin Mocha, FiraCode Nerd Font 14, `Cmd+K` clears,
  `Shift+Enter` sends Alt+Enter (a newline in Claude Code), left Option is Alt.
  Change it with `chezmoi edit ~/.config/ghostty/config`; restart Ghostty if it
  does not reload.
- Ghostty opens the login shell. For panes and agent sessions, type `herdr`
  (`herdr` module).
