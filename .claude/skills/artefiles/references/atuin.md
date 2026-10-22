# atuin: searchable, synced shell history

- Config: `~/.config/atuin/config.toml` (managed): fuzzy search, sync every 5
  minutes, workspace filter for the up arrow.
- Keys: Ctrl+R/Alt+R/Alt+F and up-arrow open the history in an fzf picker:
  `Ctrl+R`/`Alt+R` this folder, `Alt+F` and up-arrow (on a one-line command) every folder.
- Sync across machines: `atuin register` (first machine) or `atuin login`,
  then `atuin sync`. `atuin import auto` imports the old shell history.
- `atuin stats` shows the most used commands.
- Doctor: checks `atuin` and its managed config.
