# Core: every install

Installed on every machine, whatever the modules: fish, starship, git, gh,
mergiraf, uv, fnm, the FiraCode Nerd Font, and chezmoi itself. macOS gets them
from Homebrew (`brew bundle`), Linux from GitHub release downloads into
`~/.local/bin` (the externals).

## fish

The default shell. Suggestions appear as you type; `→` accepts one.

- Config: `~/.config/fish/config.fish` (managed, a template),
  `~/.config/fish/aliases.fish`, `~/.config/fish/functions/`.
- Your own settings: `~/.config/fish/local.config.fish`, sourced last and not
  managed by chezmoi. Put aliases, `set -gx` variables and PATH changes there.
- Plugins (fisher): `~/.config/fish/fish_plugins` lists catppuccin/fish,
  fish-rsync and replay.fish. `fisher update` reinstalls them.
- Theme: Catppuccin Mocha via `fish_config theme choose catppuccin-mocha`. To
  keep another theme, add `fish_config theme choose <name>` to
  `local.config.fish`.
- Abbreviations: `vba` activates `.venv`, `dea` deactivates, `G` expands to
  `| grep ""` anywhere on the line.
- `Tab` opens an fzf picker over every completion when fzf is installed
  (`shell_tools`): typing filters, `Tab`/`Shift-Tab` move, `Enter` inserts,
  `Esc` cancels. It completes the whole word under the cursor, like fish's own Tab.
- `confedit <file>` is `chezmoi edit --apply`; `confmerge <file>` is
  `chezmoi merge --apply`.
- `conda`, `miniconda` and `anaconda` are blocked: use uv.

### Running bash snippets in Fish

Fish is not bash, but recent releases accept part of its syntax. Checked on fish 4.9.2 (`fish --version`; older releases accept less):

Works in Fish as is: `$(...)` (since 3.4), `a && b || c`, `FOO=1 cmd`, `export FOO=3`, `{ a; b }` (since 4.1), `cmd1 |& cmd2`.

Still fails: `if ...; then ...; fi`, `for x in ...; do ...; done`, `VAR=$(cmd)`, `$((1 + 2))`, `f() { ...; }` and sourcing a bash file. For these, the [replay.fish](https://github.com/jorgebucaran/replay.fish) plugin (installed through `fish_plugins`, pure Fish) runs a snippet in bash and copies the variables, `PATH` changes and aliases it made into your Fish session:
- `replay 'export PATH="$HOME/.local/bin:$PATH"'`: add a folder to `PATH`
- `replay 'if [ -f "$HOME/.env" ]; then set -a; source "$HOME/.env"; set +a; fi'`: load a `.env` file
- `replay 'VERSION=$(date +%Y.%m); export VERSION'`: bash-only assignment syntax
- `replay 'eval "$(some-tool env)"'`: the pattern many tools document for bash
- `bash script.sh`, or any script with a `#!/bin/bash` shebang: runs in bash with no plugin needed

Bash functions are not copied, so a tool that exists only as a bash function (nvm, for example) is not usable in Fish through `replay`. Python virtualenvs ship a Fish script, so use `source .venv/bin/activate.fish` instead.

## Default shell

If the installer's offer to make fish the default shell was declined, the
commands are in `CHEATSHEET.md` (*Default shell*).

## starship

The prompt. Config: `~/.config/starship.toml` (managed). `starship explain`
shows what each segment means; `starship timings` shows the slow ones.

## git and gh

- `~/.gitconfig` is managed (a template: name and email come from your GitHub
  profile at init). Change it with `chezmoi edit ~/.gitconfig`.
- Aliases (`gs` status, `glog` graph log, `ghpr` new pull request, …):
  `scripts/aliases.sh git` and `scripts/aliases.sh gh`.
- `gh auth status` checks the login; `gh auth login` fixes it.
- mergiraf merges config and code files by syntax during `git merge` and
  rebases (the `merge.mergiraf` driver). `mergiraf solve <file>` retries a
  conflicted file.

## uv: Python

| Task | Command |
|---|---|
| New project | `uv init && uv lock` |
| Add a package | `uv add <pkg>` |
| Run in the project env | `uv run python script.py` |
| A tool on PATH | `uv tool install <pkg>`, `uv tool upgrade --all` |
| A one-off tool | `uvx <tool>` |

With direnv (`shell_tools`), `scripts/envrc-uv.sh --apply` writes the
`.envrc` that activates the project venv on `cd` and runs `direnv allow`
(`--nested` for a project inside another one, such as a jj workspace). It needs
a `pyproject.toml` and a `uv.lock` (`uv init && uv lock`); without `--apply` it
only prints the file.

Config: `~/.config/uv/uv.toml` (managed).

## fnm: Node

`fnm install --lts`, `fnm use <version>`, `fnm default <version>`. A
`.node-version` or `.nvmrc` in a folder switches version on `cd`.

## Health

`dotfiles_doctor` (fish) checks every tool of the selected modules and the
configs chezmoi manages for them; a ✗ makes it return 1, a ! is a warning. It
also flags conda and Docker Desktop installs, which are not allowed.
