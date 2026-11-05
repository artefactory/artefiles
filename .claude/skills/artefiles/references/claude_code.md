# claude_code: Claude Code

Claude Code, Anthropic's coding agent in the terminal: `claude`.

- macOS and Linux: Anthropic's native installer on the stable channel
  (`curl -fsSL https://claude.ai/install.sh | bash -s stable`, from
  code.claude.com/docs/en/setup), run once by `.chezmoiscripts/run_install-claude-code.sh`.
  Stable trails latest by about a week and skips releases with major
  regressions.
  No sudo. The launcher is `~/.local/bin/claude`; the versions live in
  `~/.local/share/claude/versions/`. The installer edits no shell config; the
  fish config already puts `~/.local/bin` on PATH.
- Skipped when a `claude` is already on PATH, whatever installed it (Homebrew,
  npm, apt). Without `bash` or `curl` (Alpine) the apply says so and goes on.
- Updates: the native install updates itself in the background, on the stable
  channel it was installed with; `claude update` updates now. `/config` →
  Auto-update channel (or `autoUpdatesChannel` in `~/.claude/settings.json`)
  switches to latest. Homebrew is not used, as its cask does not auto-update.
- First run: `claude` in a project signs in through the browser. `claude doctor`
  checks the install.
- Config: `~/.claude/` (settings, skills) and `~/.claude.json`.
- Doctor: checks `claude`.
