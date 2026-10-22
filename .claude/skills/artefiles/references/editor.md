# editor: Neovim

- Installs `neovim` (macOS brew; Linux release download to `~/.local/bin/nvim`).
- Config: `~/.config/nvim/init.lua` (managed, a template).
- Aliases: `vim`, `vi` and `v` open `nvim`; git uses it as its editor.
- `:checkhealth` inside nvim diagnoses plugins and providers.
- Your own changes: `chezmoi edit ~/.config/nvim/init.lua`, or keep a
  separate file you `require` from it.
- Doctor: checks `nvim`.
