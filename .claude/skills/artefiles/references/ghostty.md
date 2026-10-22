# ghostty: Ghostty terminal and Zellij

Alternative to `cmux`: pick one.

- Ghostty (macOS cask; Linux download): config `~/.config/ghostty/config`
  (managed): Catppuccin Mocha, FiraCode Nerd Font 14, `Cmd+K` clears,
  `Shift+Enter` sends Alt+Enter (a newline in Claude Code), left Option is Alt.
  Change it with `chezmoi edit ~/.config/ghostty/config`; restart Ghostty if it
  does not reload.
- Zellij: panes and tabs in one terminal. `zellij` starts a session,
  `zellij attach` resumes one, `Ctrl+P` pane mode, `Ctrl+T` tab mode, `Ctrl+O d`
  detaches.
- Doctor: checks `ghostty`.
