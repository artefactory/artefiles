# review: tuicr code review in the terminal

`review` wraps tuicr; `review <Tab>` lists the subcommands.

| Command | Reviews |
|---|---|
| `review` | uncommitted changes |
| `review file <path>` | one file or folder |
| `review branch [base]` | this branch against `main` (or `base`) |
| `review commit [rev]` | the last commit (or `rev`) |
| `review pr <n>` | a GitHub pull request |
| `review list` | saved review sessions |
| `review comments` | the comments of a session |

Any other subcommand goes to `tuicr` as is. Config: `~/.config/tuicr/config.toml`
(managed). Linux: tuicr comes from its release by a script.
