# command:  rust-analyzer
# purpose:  The Rust language server: completion, types on hover, go-to-definition, inline errors.
# why:      Stage 7 installs it with Rust, and Neovim and Helix start it for
#           .rs files. It is what makes a Rust project navigable in the editor.
# see:      cargo, nvim, hx

## Use
The editor runs it; there is nothing to start by hand. Open a file inside
a Cargo project and it indexes the project, then answers the editor.

## Examples
    rust-analyzer --version              # which version is installed
    rust-analyzer diagnostics .          # the project's errors, from the shell
    which rust-analyzer                  # which one the editor will find

## Options
diagnostics DIR   print the diagnostics for the project in DIR
--version         the version

## Notes
- It needs the standard library's source: `rust-src`, which the Rust row
  installs.
- With rustup installed, `~/.cargo/bin` comes first on PATH and its
  `rust-analyzer` is a proxy that says "unavailable for the active
  toolchain" until `rustup component add rust-analyzer`.
- The first index of a large project takes a while and a lot of memory
  on a small Pi.
