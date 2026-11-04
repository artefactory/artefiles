# runme: Runme

Runs the named shell blocks of the README and the cheatsheet, so a manual step is one command.

- From the source directory (`chezmoi cd`): `runme list`, `runme print <name>`, `runme run <name>`.
- Cells that install, change the login shell or delete files are skipped by `runme run --all`.
- Doctor: checks `runme`.
