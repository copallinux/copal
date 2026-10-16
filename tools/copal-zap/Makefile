# copal-zap -- the front door.
#
#   make            build (release)
#   make check      unit tests, the whole-life tests against a real xorriso, clippy
#   make install    ~/.local/bin/copal-zap -> target/release/copal-zap
#
# INSTALL IS A SYMLINK, NOT A COPY. A copied binary goes stale the moment the
# next build lands and nothing says so; a link is always the last build.
#
# The whole-life tests burn to image files with the real xorriso, and skip
# (saying SKIPPED) when there is none. Point XORRISO at one to run them on a
# machine without it installed.

CARGO  ?= cargo
PREFIX ?= $(HOME)/.local
BIN     = target/release/copal-zap
GUIBIN  = gui/target/release/copal-zap-gui

# The window is its own crate (gui/), built from gui/ so its .cargo/config.toml
# -- dynamic linking, which a Wayland window needs on musl -- applies. NEVER
# with RUSTFLAGS set: they override that file and the window will not open.

.PHONY: all build check clippy install uninstall clean gui gui-build gui-check gui-install

all: build

build:
	$(CARGO) build --release

check:
	$(CARGO) test
	$(CARGO) clippy --all-targets -- -D warnings

install: build
	@mkdir -p "$(PREFIX)/bin"
	ln -sfn "$(CURDIR)/$(BIN)" "$(PREFIX)/bin/copal-zap"
	@echo "linked $(PREFIX)/bin/copal-zap -> $(CURDIR)/$(BIN)"

uninstall:
	rm -f "$(PREFIX)/bin/copal-zap" "$(PREFIX)/bin/copal-zap-gui"

gui-build:
	cd gui && $(CARGO) build --release

gui: gui-build
	./$(GUIBIN)

gui-check:
	cd gui && $(CARGO) test && $(CARGO) clippy --all-targets -- -D warnings

gui-install: gui-build
	@mkdir -p "$(PREFIX)/bin"
	ln -sfn "$(CURDIR)/$(GUIBIN)" "$(PREFIX)/bin/copal-zap-gui"
	@echo "linked $(PREFIX)/bin/copal-zap-gui -> $(CURDIR)/$(GUIBIN)"

clean:
	$(CARGO) clean
	cd gui && $(CARGO) clean
