# pi: pi coding agent

pi (pi.dev), a minimal, extensible coding agent in the terminal: `pi`.

- macOS and Linux: pi's official installer (`https://pi.dev/install.sh`), the
  managed install, run once with fnm's default Node by
  `.chezmoiscripts/run_after_install-pi.sh`. No sudo. Releases live in
  `~/.pi/agent/install/`, with all dependencies pinned; the launcher is
  `~/.local/bin/pi`.
- At a terminal the installer shows one menu on the terminal: Enter installs.
  Without a terminal (CI, containers) it installs without asking.
- Needs Node.js 22.19 or newer and npm: the install is skipped, and retried on
  the next apply, while fnm's default Node is older. pi runs on the Node on
  PATH, so a project whose `.node-version` selects an older Node cannot run it.
- Skipped when a `pi` is already on PATH, whatever installed it.
- Updates: not automatic. `pi update` updates it.
- Config: `~/.pi/agent/settings.json`.
- Doctor: checks `pi`.
