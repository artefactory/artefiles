# shell_tools: bat, eza, fd, fzf, ripgrep, zoxide, direnv

Modern replacements for everyday commands; fish aliases make them the default.

| Tool | Replaces | Use |
|---|---|---|
| eza | `ls` | `ls`, `ll` (long, with git status), `lt` (tree) |
| bat | `cat` | `cat file` highlights syntax; config `~/.config/bat/config` |
| fd | `find` | `fd pattern`; `ff` files only, `fdir` folders only |
| ripgrep (rg) | `grep -r` | `rg pattern`: smart case, hidden files included |
| fzf | — | `Tab` picker over completions; `Ctrl+T` files |
| zoxide | `cd` | `cd foo` jumps to the most used folder matching `foo` |
| direnv | — | loads `.envrc` per folder; `direnv allow` after each edit |

Every alias and helper function of a tool: `scripts/aliases.sh <tool>`.

- direnv: put secrets in `.envrc.local` (ignored by the global gitignore), never
  in `.envrc`. For Python projects see `layout uv` in core.md.
- `command ls` or `\ls` bypasses an alias.
- Doctor: checks each tool.
