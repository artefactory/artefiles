# antigravity: Google Antigravity (macOS)

Google Antigravity, Google's agent-first IDE: a desktop editor where agents
plan, edit and run code across the editor, the terminal and a browser.

- macOS only: the `antigravity` Homebrew cask installs Antigravity.app in
  Applications. On Linux the module installs nothing; Google ships only a
  tarball there (antigravity.google/download).
- Open it from Applications or Spotlight; the first launch signs in with a
  Google account.
- The app updates itself, so `brew upgrade` skips it; `brew upgrade --cask
  --greedy antigravity` forces a Homebrew update. Needs macOS 13 or later.
- Doctor: no check, as the cask puts no command on PATH.
