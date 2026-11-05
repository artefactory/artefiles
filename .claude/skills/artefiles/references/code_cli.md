# code_cli: VS Code CLI (Linux)

The standalone VS Code CLI, for machines without the desktop app: a server, a
VM or a container you want to open from VS Code on your laptop.

- Linux only: downloaded from code.visualstudio.com to `~/.local/bin/code-cli`
  and refreshed every four weeks, for x64, arm64 and 32-bit ARM (armhf); other
  arches get nothing. On macOS the `vscode` module's `code` already has the
  same commands (`code tunnel`), so this module installs nothing there even
  though it is selected by default.
- Named `code-cli`, not `code`, so it never hides the desktop app's `code`.
- `code-cli tunnel` signs in with GitHub or Microsoft and prints a link; open it
  in a browser or from VS Code (Remote - Tunnels) to work on this machine.
  `code-cli tunnel service install` keeps the tunnel running after logout.
- `code-cli serve-web` serves VS Code in a browser on this machine.
- Doctor: checks `code-cli` on Linux, on the arches that get it.
