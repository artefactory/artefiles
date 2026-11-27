# pi_kit: Artefactory's pi-kit

[pi-kit](https://github.com/artefactory/pi-kit), the team's pi packages and
default settings, is set up by `.chezmoiscripts/run_after_zzzzzz_install-pikit.sh`,
which runs the kit's own `install.sh`.

- Opt-in: not selected by default, offered once to an existing install by the
  new-module checklist at a terminal. `install.sh --yes` and applies without a
  terminal never select it. To change your choice, run
  `chezmoi init --prompt && chezmoi apply`.
- Needs the [`pi`](pi.md) module and an `@artefact.com` email, in any case: the
  `email` that `chezmoi data` shows. Without both, the script does not run. The
  email selects who gets the kit and proves nothing about the address.
- Needs `jq` (from the `pi` module), `git`, `curl`, `perl`, pi, fnm's default
  Node 22.19 or newer, a GitHub SSH key that works without a prompt
  (`ssh -T git@github.com`, loaded in an agent if it has a passphrase) and
  github.com in `known_hosts`: the script never accepts a host key for you.
- Before running the installer, `git ls-remote` must read the kit and every git
  source in its `packages.txt`, some of them private.
- While one of these is missing it says which, changes nothing and tries again
  on the next apply. A failed installer download or installer run fails the
  apply, and the next one runs it again; packages installed before the failure
  stay. It runs after the other scripts, so they are not held back.
- On Linux git fetches the kit's `git@github.com:` packages over HTTPS, with the
  `gh` login (`gh auth login`).
- Settings you already have win over the kit's defaults. A
  `~/.pi/agent/settings.json` that is not a JSON object is left alone. A
  `PI_CODING_AGENT_DIR` pointing elsewhere skips the setup.
- Installs once. After a success, or when the kit's source
  (`git:git@github.com:artefactory/pi-kit`) is already in pi's settings, it
  writes `~/.local/state/artefiles/pi-kit.installed` (under `XDG_STATE_HOME`
  when set) and never installs again, even if you remove the kit.
- To run it again: `pi remove git:git@github.com:artefactory/pi-kit`, delete
  that file, then `chezmoi apply`. Or run the kit's installer yourself.
- Packages the kit adds later do not reach your machine by themselves.
  `pi update --extensions` updates the installed ones. If the installer cannot
  merge the kit's defaults it does not fail, and that merge is not retried.
- The installer and its package list are read from the kit's `main` branch, not
  from a pinned release.
- Doctor: warns when the module is selected and pi's settings do not list the
  kit.
