# rust: Rust toolchain

- macOS: brew `rust`. Linux: `rustup` installed by a script, which runs
  `rustup update` only when `rustup check` reports an update.
- `cargo build`, `cargo test`, `cargo install <crate>` (binaries go to
  `~/.cargo/bin`).
- Doctor: checks `rustc` and `cargo`.
