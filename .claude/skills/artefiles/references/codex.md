# codex: Codex CLI

OpenAI's Codex CLI, a coding agent in the terminal: `codex`.

- macOS: the `codex` Homebrew cask; `brew upgrade` updates it.
- Linux: the static musl build from the latest GitHub release of openai/codex
  (`codex-<arch>-unknown-linux-musl.tar.gz`), as `~/.local/bin/codex`; each
  `chezmoi apply` fetches a newer release when there is one.
- First run: `codex` signs in with a ChatGPT account or an API key.
- Config: `~/.codex/config.toml`.
- Doctor: checks `codex`.
