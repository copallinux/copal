# command:  cargo
# purpose:  Rust's build tool and package manager: new, build, run, test, install.
# why:      Stage 7 installs Rust on every port, the Zero included, and
#           several checkouts in ~/code are Rust: copal-build compiles them
#           with cargo and links what they make into ~/.local/bin.
# see:      gdb, git, make, copal-build

## Use
Every Rust project is a directory with a `Cargo.toml`. `cargo run`
builds and runs it; `cargo build --release` makes the fast version in
`target/release`. Dependencies named in `Cargo.toml` are fetched from
crates.io and built with it.

## Examples
    cargo new hello && cd hello          # a new project, with git
    cargo run                            # build (debug) and run
    cargo build --release                # optimised, into target/release/
    cargo check                          # type-check only: much faster than a build
    cargo test                           # run the tests
    cargo clippy                         # lints: common mistakes, better idioms
    cargo fmt                            # format the code
    cargo install ripgrep                # build a tool into ~/.cargo/bin (on PATH)

## Options
new NAME            a new project (--lib for a library)
build / run         compile / compile and run; --release for optimised
check               check without producing a binary
test                build and run the tests
clippy / fmt        lint / format
add CRATE           add a dependency to Cargo.toml
install CRATE       build and install a program
-j N                parallel jobs
--offline           use only what is already downloaded

## Notes
- This is Alpine's Rust, a release or two behind. A crate that says
  "requires rustc 1.NN or newer" wants rustup -- and once rustup is in,
  `~/.cargo/bin` comes first on PATH and its cargo replaces this one.
  `which cargo` says which you are running.
- rustc is an LLVM compiler and hungry: a release build with dependencies
  can want more than 512 MB. On a Zero it works because of zram, slowly;
  `-j1` keeps it from running out.
- `cargo build` without `--release` makes a debug build that can run ten
  times slower. Measure the release one.
