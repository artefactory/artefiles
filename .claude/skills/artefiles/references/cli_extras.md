# cli_extras: faster CLI replacements

| Tool | Command | Use |
|---|---|---|
| rip2 | `rip` | `rm` is aliased to `rip`: files go to a graveyard. `rmundo` restores the last one (all aliases: `scripts/aliases.sh rip`) |
| dust | `dust` | disk usage as a tree (`du`) |
| dysk | `dysk` | mounted filesystems and free space (`df`) |
| procs | `procs` | process list with search (`ps`): `procs python` |
| sd | `sd` | find and replace (`sed`): `sd 'old' 'new' file` |
| choose (brew `choose-rust`) | `choose` | pick fields (`cut`/`awk`): `choose 0 2` |
| hyperfine | `hyperfine` | benchmark commands: `hyperfine 'cmd a' 'cmd b'` |
| bottom | `btm` | system monitor (`top`/`htop`) |

- `rm` deletions are recoverable until `rmclean`; `command rm` deletes for real.
- Doctor: checks each tool.
