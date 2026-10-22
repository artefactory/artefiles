---
name: artefiles
description: 'Install, update, debug, customize and use an artefiles setup (chezmoi dotfiles: fish, starship, git and modern CLI tools). Use when installing artefiles or fixing a failed install.sh, updating or rolling back a bad update, forking it and following its releases, changing a config it manages or its modules, running chezmoi (status, diff, apply, edit, re-add, merge), or asking how to use a tool it installs (lazygit, atuin, zoxide, uv, direnv, duckdb, k9s, az, gcloud, colima, docker). Also use when a config "got reverted", "chezmoi apply overwrote my change", or dotfiles_doctor reports a problem.'
---

# artefiles

artefiles is a chezmoi source: chezmoi renders the files of this repository into
the home directory. Every config exists twice, the **source** (this repository,
`chezmoi source-path`) and the **target** (the file in `~`). Most damage comes
from writing one over the other without looking, so every task below starts
with the drift check.

The helpers in `scripts/` read the machine and change nothing unless given
`--apply`. Run them as `sh scripts/<name>.sh` from this skill's folder: an
install with `gh skill` does not keep their executable bit.

Pick the section for the task:

| Task | Section |
|---|---|
| Install, or fix a failed install | *Install and debug an install* |
| Update, or undo a bad update | *Update and debug an update* |
| Change a config, fork, follow releases | *Customize and fork* |
| Any chezmoi command | *Using chezmoi* |
| How to use a tool | *Tools by module* |
| Change artefiles itself | *Changing artefiles* |

## The drift check: before any `chezmoi apply`

A bare `chezmoi apply` overwrites every target that differs from the source,
including fixes made by hand in `~`. Run `scripts/drift.sh` first: it lists
each differing target with the command that keeps the user's version (`re-add`
for a plain file, a merge for a template) and the one that takes the source,
and warns about uncommitted edits in the source. Decide per target, then apply
only those: `chezmoi apply <target>...`.

**Example.** A user's fish abbreviations "got reverted" after an update.

```sh
scripts/drift.sh                         # .config/fish/config.fish: differs
chezmoi diff ~/.config/fish/config.fish  # the source drops their abbr lines
# They wrote the lines in the target by hand: move them to
# ~/.config/fish/local.config.fish, which chezmoi does not manage, then
chezmoi apply ~/.config/fish/config.fish
```

## Install and debug an install

- `sh -c "$(curl -fsLS https://raw.githubusercontent.com/artefactory/artefiles/main/install.sh)"`
  installs the latest release. `ARTEFILES_VERSION=<tag or branch>` picks
  another one; `GH_TOKEN=<token>` signs in without a browser. From a checkout,
  `./install.sh --dry-run` checks the machine and prints the chezmoi commands
  without changing anything; `--destination <dir>` installs elsewhere.
- The installer checks the machine first (preflight) and stops before any
  change if something is missing; its message says what to install.
- **Modules** are chosen in a checklist (`select-modules.sh`) and saved in
  chezmoi's config (`~/.config/chezmoi/chezmoi.toml`, keys `modules`,
  `modulesOffered`, `modulesVersion`).
- **Backup.** Before the first apply, every file the install would change is
  copied to `~/.local/state/artefiles/backup-<date>/files/`, with the files it
  creates listed in `created.txt`.
- **Undo the install.** `sh install.sh --restore <backup folder>` asks y/N,
  copies the saved files back, deletes what the install created and removes
  chezmoi's config and state. A source checkout of the user's own is kept;
  software the install added stays.

**Debugging a failed install.** Run `scripts/diagnose.sh`: one report with the
tool versions, the source's release and edits, GitHub access, `chezmoi doctor`
and `dotfiles_doctor` problems, the drift count and the install backups. Then:

- The apply runs with `--keep-going`; failed steps are listed last as
  `chezmoi: <script>: exit status N`, with their own output above. Fix the
  cause, then `chezmoi apply --keep-going`: only failed scripts run again.
- Trace a script: `chezmoi execute-template < <source script> | sh -x`. A broken
  template: `chezmoi execute-template < <file>.tmpl` prints the line.
- `403 API rate limit`: on Linux every chezmoi command (and so every script
  here) renders the download list through the GitHub API, even with
  `--exclude=externals`. `export GITHUB_TOKEN="$(gh auth token)"`, then retry.
- Rerun scripts that succeeded: `chezmoi state delete-bucket --bucket=entryState`
  (`run_onchange_`) or `--bucket=scriptState` (`run_once_`).

Verify: `dotfiles_doctor` returns 0, and `chezmoi verify` exits 0.

## Update and debug an update

- Read the release notes first: `gh release view --repo artefactory/artefiles`.
  Breaking changes come first, each with what to do.
- `chezmoi update` on a release install moves to the newest release tag and
  prints `moved from <old> to <new>`; on a branch it runs
  `git pull --autostash --rebase` (`[update]` in `.chezmoi.toml.tmpl`).
- On a machine with drift: `chezmoi update --apply=false`, then the drift
  check, then apply target by target.
- **New modules.** When a release adds modules the user has never been shown,
  the update opens the checklist with their modules checked and the new ones
  marked "(new)". The answer is saved, but chezmoi cannot install it during the
  same run: a warning block says `NOT INSTALLED YET`, and `chezmoi apply`
  installs it. Without a terminal, the offer waits for the next apply at one.
- **Change modules** at any time: `chezmoi init --prompt && chezmoi apply`.
  Plain `chezmoi init` keeps the saved modules.

**A bad update.**

1. What changed: `git -C "$(chezmoi source-path)" log --oneline <old>..<new>`
   (the tags of the `moved from` line), and the release notes.
2. A config broke: `scripts/drift.sh`, then fix it in the source or in
   `local.config.fish`.
3. Back to the previous release: `scripts/rollback.sh` prints the plan;
   `scripts/rollback.sh --apply` checks the tag out and runs the drift check.
   The next `chezmoi update` moves forward again.
4. Report the problem with the `scripts/diagnose.sh` output.

Verify: `git -C "$(chezmoi source-path)" status` is clean and
`dotfiles_doctor` returns 0.

## Customize and fork

- **Machine-only settings** go in `~/.config/fish/local.config.fish`, which
  `config.fish` sources last and chezmoi does not manage. No conflicts on update.
- **Edit a managed config:** `chezmoi edit <target>`, then `chezmoi diff <target>`
  and `chezmoi apply <target>`. Such an edit lives in the source and conflicts
  with later releases unless it is committed in a fork.
- **A target edited by hand:** bring it back to the source.
  - Plain file: `chezmoi re-add <target>`.
  - Template (`.tmpl`): `re-add` skips templates. Port the change into the
    `.tmpl`, inside the right `# [[ if … ]] #` block, or `chezmoi merge <target>`.
    Then `chezmoi diff <target>` must be empty.
- **Templates** select per-machine variants with `.modules` and `.chezmoi.os`.
  Keep other OSes' and modules' variants intact. Some templates use custom
  delimiters declared on their first line, for example
  `# chezmoi:template:left-delimiter="# [[" right-delimiter="]] #"` in
  `dot_config/fish/config.fish.tmpl`; searching for `{{` misses them.
- **Secrets** never go in a config, a template or an `.envrc`: read them at
  load time (`op read` with 1Password) or keep them in `.envrc.local`, which
  the global gitignore excludes.

**Fork and follow artefiles releases.**

1. Fork `artefactory/artefiles` on GitHub. New machine: run `./install.sh` from
   a clone of the fork. Existing install:
   `git -C "$(chezmoi source-path)" remote set-url origin <fork URL>`.
2. Commit your changes in the fork on a branch (`main`); `chezmoi update` then
   pulls the fork.
3. Take a release: `scripts/upstream.sh` shows the newest artefiles release and
   whether the fork has it; `--apply` adds the upstream remote, fetches and
   merges it, then runs the drift check. With `git_advanced`, mergiraf merges
   config files by structure.
4. Then apply what the drift check showed, and `git push` to the fork.

## Using chezmoi

| Command | Does |
|---|---|
| `chezmoi status --exclude=scripts,externals` | targets that differ from the source |
| `chezmoi diff [<target>]` | what an apply would change |
| `chezmoi apply [<target>...]` | write the source into the targets (`--keep-going` past failures, `--dry-run --verbose` to preview) |
| `chezmoi edit <target>` | open the source of a target (`--apply` to apply on save) |
| `chezmoi re-add <target>` | copy a hand-edited plain target back to the source |
| `chezmoi merge <target>` | three-way merge of target, source and last applied state |
| `chezmoi managed` | every managed path (`--include=scripts` for scripts) |
| `chezmoi data` | the template data: modules, name, email, OS |
| `chezmoi execute-template < <file>` | render a template |
| `chezmoi cd` | a shell in the source |
| `chezmoi update` | pull the new release, then apply |
| `chezmoi init --prompt` | ask the questions again (modules, email) |
| `chezmoi verify` | exits 1 if any target differs |
| `chezmoi doctor` | chezmoi's own environment |
| `chezmoi forget <target>` | stop managing a target, keep the file |

- Files in the source carry their attributes in their names: `dot_` (a
  leading `.`), `private_`, `executable_`, `.tmpl` (a template).
- `run_onchange_*` scripts run again when their rendered content changes,
  `run_once_*` once per content, `run_*` on every apply; `before_`/`after_` order
  them around the file writes. `.chezmoiremove` deletes targets on apply
  without asking (`chezmoi diff` shows each removal first).

## Tools by module

Run `scripts/modules.sh`: it prints the modules this machine installs and the
guides to read, `references/core.md` plus one per module. Each guide says what
the module installs and the everyday commands. Answer from them, not from
memory: they match what this release installs.

For one tool, `scripts/tool-info.sh <tool>` (a command or a package name) says
which module installs it, whether it is installed and its version, the configs
chezmoi manages for it and its fish aliases; `scripts/aliases.sh <tool>` lists
only the aliases. A tool whose module is not selected: say which module
installs it and how to add it (`chezmoi init --prompt && chezmoi apply`).

Status checks that say what to run next: `scripts/cloud-status.sh` (gcloud,
az, kubectl), `scripts/containers-status.sh` (Colima, docker, buildx) and
`scripts/hooks-status.sh` (pre-commit or prek).

## Changing artefiles

**Prefer the tools' standard features.** Before adding or keeping an override
(a shadowing file, a wrapper, a cache), check whether the tool now ships it.

- fish loads user `conf.d/` before `vendor_conf.d/`, and a file with the same
  name shadows the vendor one; `completions/` shadows `vendor_completions.d/`.
- direnv's built-in `layout uv` (2.38 and later) needs a `pyproject.toml` and a
  `uv.lock`; its sync is exact unless called as `layout uv --inexact`.
- fish 4.3 moved theme colours and `fish_key_bindings` to global scope; the
  theme is chosen with `fish_config theme choose`.

**Where a tool comes from.**

| Where | What |
|---|---|
| `.chezmoidata/packages.yaml` | macOS brews and casks, per module |
| `.chezmoiexternal.toml.tmpl` | Linux binaries from GitHub releases, per module |
| `.chezmoiscripts/linux/` | Linux installs a single download cannot do (kubectl, gcloud, az) |
| `.chezmoiscripts/` (root) | both OSes: `uv tool` installs (nbdime, harlequin) and the new-module offer |

A script that needs a tool from the externals (uv, bat, fnm) must be an
`after_` script; `tests/externals.bats` checks it.

**Adding a module.** A terminal UI goes in the module of the tool it drives
(lazygit with `git_advanced`, k9s with `kubernetes`).
`scripts/check-module.sh <name> <checkout>` reports which of these places is
missing:

1. Its choice line, `<name> | <help>`, in `.chezmoi.toml.tmpl` (at most 110
   characters). Existing installs are offered it on their next update.
2. `.chezmoidata/packages.yaml` for macOS.
3. Linux: an entry in `.chezmoiexternal.toml.tmpl` or a script, gated in
   `.chezmoiignore`.
4. A `__check_tool_with_configs` line in
   `dot_config/fish/functions/dotfiles_doctor.fish.tmpl`.
5. Its row in the `README.md` module table, and `references/<module>.md` here
   (`tests/claude_skill.bats` checks that every module has one naming its tools).
6. The module count in `tests/module_help.bats`, and a test for each OS.

Bump `.chezmoitemplates/modulesVersion` only when existing installs must gain
a module without being asked; `.chezmoitemplates/modules` then migrates them.

**Removing a config.** Delete the source file, list the target in
`.chezmoiremove` with a line of the text artefiles shipped in it (a file a user
wrote at the same path survives), list the state it owned too (caches, state
files), and extend `tests/chezmoiremove.bats`.

**Testing.**

| What | Command |
|---|---|
| Unit tests | `GITHUB_TOKEN="$(gh auth token)" bats tests/` (one file: `bats tests/<name>.bats`) |
| A new user's install, without touching your machine | `./sandbox.sh` (`--modules a,b` skips the prompts) |
| A full Linux install in a container | `./docker-test.sh` |
| CI | `.github/workflows/ci.yml`: a full install on macOS and Linux for every ready pull request |

A test runs on a fake home (`tests/helpers/setup.bash`: `mk_fake_home`,
`seed_chezmoi_config`, `chezmoi_render`, `chezmoi_apply`) and must fail
without the change.
