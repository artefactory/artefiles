# herdr: terminal workspace for coding agents

herdr (herdrdev/herdr, Apache-2.0) runs terminals and coding agents in a
background server: `herdr` starts or reattaches, `Ctrl+B` is the prefix,
`Ctrl+B q` detaches and leaves the agents working.

- Panes: split them, and each one shows whether its agent is working, blocked
  or idle, so the agent waiting for an answer stands out.
- macOS: the `herdr` Homebrew formula; `brew upgrade` updates it.
- Linux: the binary of the latest GitHub release of herdrdev/herdr
  (`herdr-linux-<arch>`), as `~/.local/bin/herdr`; each `chezmoi apply` fetches
  a newer release when there is one.
- Started by hand, like tmux: type `herdr` in any terminal; Ghostty itself
  opens the login shell.
- Configuration and plugins: https://herdr.dev/docs/
- Doctor: checks `herdr`.
