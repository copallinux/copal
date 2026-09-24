# playbook: stage-dev
# source:   copal
# origin:   stage
# stage:    7
# category: Toolchain
# step:     Compilers, editors, Claude Code and the ~/code checkouts
# weight:   13
# levels:   medium full
# summary:  Installs the compilers, debuggers, Neovim and Claude Code, and clones your repositories
#           into ~/code and builds them. The machine arrives ready to work on its own projects.

stage_dev() {
    say "Stage 7: development environment"

    # The toolchain is 2-3 GB. Before this check existed, running it diskless
    # is what filled a 2.9 GB tmpfs and wedged a machine.
    require_disk_root "The toolchain (2-3 GB)" || return 0
    cat <<'MSG'
    Modelled on Omarchy's tool choices, with the pieces that need a GPU or a
    fast machine swapped for equivalents this board can actually run. The
    keyboard-driven, TUI-first, one-theme-everywhere idea carries over intact;
    Hyprland, Alacritty, Walker and Nautilus do not.
MSG
    require_network || return 1

    # --- the C toolchain ---------------------------------------------------
    # build-base is gcc, g++, make, musl-dev and binutils in one package.
    say "C toolchain and debugger"
    apk add build-base gdb
    add_optional git ctags pkgconf

    # --- editors -----------------------------------------------------------
    say "Editors"
    # Neovim is Omarchy's editor. LazyVim is not viable here: it compiles
    # treesitter parsers with gcc on first launch, which on a single ARMv6
    # core takes the better part of an hour and then wants more RAM than this
    # board has. A hand-written config gives the same core workflow instantly.
    if try_add neovim; then EDITOR_BIN=nvim; else add_optional vim; EDITOR_BIN=vim; fi
    note "editor: $EDITOR_BIN"
    add_optional neovim-doc >/dev/null 2>&1
    # Geany: a real GUI IDE with a build system, light enough for this board.
    add_optional geany

    # --- languages ---------------------------------------------------------
    # Which of these exist depends on the port, and the differences are real
    # rather than cosmetic. Every name below was checked against the v3.24
    # APKINDEX for armhf, armv7 and aarch64:
    #
    #   everywhere   Rust (and rust-analyzer), Go (and gopls), Fortran, PHP 8.3
    #                with Composer and Xdebug, Clang 22, OCaml, Lua, Perl, Ruby,
    #                Tcl, Nim, Elixir, Racket, SBCL, Guile, CHICKEN, tcc, R
    #   aarch64 only Haskell (GHC, cabal, hlint), Zig, Crystal, OpenJDK, Delve
    #   not armhf    .NET, Valgrind
    #
    # HASKELL is the one that will disappoint on a Zero and it is worth being
    # blunt about why: GHC is not built for ARMv6 or ARMv7 by Alpine, and it is
    # not the kind of thing you work around -- GHC bootstraps from a previous
    # GHC, so there is no small path to one. On a Pi 3/4/5 it is a single
    # 'apk add ghc cabal' and it works. On a Zero the nearest thing in spirit
    # is OCaml, which IS built for armhf: strict rather than lazy, but the same
    # ML type system, pattern matching and inference, and its native compiler
    # is small and quick enough for this board.
    #
    # FORTH has no gforth in Alpine on any architecture. RetroForth is packaged
    # everywhere and is a real, actively maintained Forth-family language, so
    # that is what gets installed. It is not ANS Forth: the vocabulary differs.
    # The guide says so rather than letting you discover it at the prompt.
    #
    # RUST is offered on every port including the Zero, with one caveat stated
    # up front rather than found out: rustc is an LLVM front end, a release
    # build of a crate with dependencies routinely wants more than 512 MB, and
    # on one ARMv6 core it is slow. It works -- 'cargo build' on a hello-world
    # finishes -- but stage 5's zram is doing real work behind it. On a Pi 4 or
    # 5 none of that applies.
    say "Language toolchains"
    dev_languages_core
    dev_languages_optional
    configure_git_identity
    # Claude Code BEFORE the checkouts, because saying yes to it is what
    # installs node -- and npm is what one of the default checkouts builds
    # with. The other way round, copal-build skipped codexofconquest on every
    # machine that would have had npm a minute later.
    install_claude_code
    dev_checkout_deps
    clone_user_repos

    say "AVR toolchain (Arduino-class microcontrollers)"
    # The Arduino IDE itself is Electron/Java and will not run here. The
    # toolchain underneath it is small and does the same job from a Makefile.
    add_optional gcc-avr avr-libc avrdude

    # --- Omarchy-style shell tools ----------------------------------------
    say "Shell tooling"
    # These are the Omarchy CLI stack. Several are Rust or Go, and armhf
    # availability varies by release -- each is attempted independently.
    add_optional ripgrep fd fzf bat eza zoxide tmux lazygit btop

    # --- editor configuration ---------------------------------------------
    # One config, sourced by both vim and nvim, so the two never drift.
    say "Writing the editor configuration"
    cat > /tmp/vimrc.$$ <<'VIMRC'
" Generated by copal-init.sh. Deliberately plugin-free: on this board every
" plugin is startup latency and RAM, and the built-ins cover the workflow.
set nocompatible

" THE LEADER IS SPACE, and it is set before the first mapping in this file
" because a mapping made with the old leader keeps the old leader forever.
"
" Space is LazyVim's leader, which is Omarchy's editor, and the reason to
" match it is not fashion: every LazyVim key list on the internet, and every
" answer anyone gives you about Neovim, is written in Space. The default
" backslash is a key nobody's fingers know and half the keyboards in the
" world put somewhere different. Space is under both thumbs on all of them.
"
" Space is also a motion in normal mode -- it moves the cursor right, which
" is what 'l' is for -- so nothing of value is lost. maplocalleader keeps the
" backslash for filetype-local maps, which is the LazyVim arrangement too.
let mapleader = " "
let maplocalleader = "\\"
nnoremap <Space> <Nop>

syntax on
filetype plugin indent on

set number
set expandtab shiftwidth=4 tabstop=4 softtabstop=4 autoindent smartindent
set incsearch hlsearch ignorecase smartcase
set hidden nowrap scrolloff=3 sidescrolloff=5
set backspace=indent,eol,start
set wildmenu wildmode=longest:full,full
set laststatus=2
set mouse=a
set nobackup nowritebackup
set updatetime=500
set path+=**
set tags=./tags;,tags;
" Space is the leader now, so it has to wait to find out whether a whole
" chord was meant. Long enough to type one deliberately, short enough that a
" mistake gives the key back before you notice.
set timeoutlen=500

" Tokyo Night-ish, using only colours the terminal already defines, so this
" needs no colour scheme file and no truecolour support. Neovim replaces this
" from ~/.config/nvim/theme.lua, which follows the desktop's theme; vim keeps
" what is set here.
set background=dark
silent! colorscheme habamax
highlight Normal ctermbg=NONE

set statusline=%f\ %m%r%h%w%=%y\ %l:%c\ %P

" --- building ---------------------------------------------------------------
" :make runs the Makefile and puts errors in the quickfix list; ]q and [q walk
" them. This is the whole compile-fix loop, built in.
set errorformat^=%-G%f:%l:\ warning:%m
nnoremap <F5> :wa<CR>:make<CR>
nnoremap <F6> :wa<CR>:make run<CR>
nnoremap ]q :cnext<CR>
nnoremap [q :cprevious<CR>

" --- LazyVim's key shape, on built-ins --------------------------------------
" The prefixes below are LazyVim's, and they are the reason this file uses
" them: <leader>c is code, <leader>b is buffers, <leader>s is search,
" <leader>g is git, <leader>x is the diagnostic and quickfix lists,
" <leader>d is debugging. Neovim adds the richer versions of several of these
" in ~/.config/nvim/keys.lua; vim gets the half that needs no Lua.
nnoremap <leader>xq :copen<CR>
nnoremap <leader>xl :lopen<CR>

" Buffers are LazyVim's tabs: Shift+H and Shift+L walk them, <leader>bd
" closes one. :bdelete would close the window with it, so the two-step keeps
" the window and moves it to the previous buffer first.
nnoremap <S-h> :bprevious<CR>
nnoremap <S-l> :bnext<CR>
nnoremap <leader>bd :bprevious<bar>bdelete #<CR>
nnoremap <leader>bb :buffers<CR>:buffer<Space>

" --- debugging --------------------------------------------------------------
" Termdebug ships with vim and neovim: a real gdb session with breakpoints,
" stepping and variable inspection, no plugin manager involved.
packadd! termdebug
let g:termdebug_wide = 1
nnoremap <F4>  :Termdebug<CR>
nnoremap <F9>  :Break<CR>
nnoremap <F21> :Clear<CR>
nnoremap <F10> :Over<CR>
nnoremap <F11> :Step<CR>
nnoremap <F12> :Finish<CR>
nnoremap <F8>  :Continue<CR>
" <leader>e used to be :Evaluate here. It is the file explorer in LazyVim and
" that is the more-reached key by a wide margin, so Termdebug's evaluate
" moved under the debug prefix where the rest of its keys would live.
nnoremap <leader>de :Evaluate<CR>
nnoremap <leader>db :Break<CR>
nnoremap <leader>dc :Continue<CR>

" --- files ------------------------------------------------------------------
" netrw is the sidebar. :Lexplore opens it on the left and toggles closed on
" the same key, which is <leader>e in LazyVim and <leader>e here.
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_winsize = 25
nnoremap <leader>e :Lexplore<CR>
nnoremap <leader>ff :find<Space>
nnoremap <leader><Space> :find<Space>
" Ctrl+W W already jumps between the sidebar and the editor -- that is vim's,
" not a plugin's, and it is what LazyVim's key list means by the same chord.
nnoremap <C-Left>  :vertical resize -5<CR>
nnoremap <C-Right> :vertical resize +5<CR>

" LazyVim's neo-tree sidebar answers a, A, d, m and r; netrw spells the same
" five differently. Teach netrw the LazyVim letters, buffer-locally, so the
" published key list is true here as well. netrw's own bindings are untouched
" everywhere they do not collide.
augroup copal_netrw_keys
  autocmd!
  " nnoremap, not nmap, and that is load-bearing: 'A' is mapped to netrw's
  " 'd' while 'd' is itself being mapped to netrw's 'D'. Recursive mappings
  " would send A through both and delete the file you meant to create a
  " directory next to.
  autocmd FileType netrw nnoremap <buffer> a %
  autocmd FileType netrw nnoremap <buffer> A d
  autocmd FileType netrw nnoremap <buffer> d D
  " netrw has no separate move: R renames, and a rename that includes a path
  " moves. So r and m are the same key underneath, as they nearly are in
  " neo-tree too.
  autocmd FileType netrw nnoremap <buffer> r R
  autocmd FileType netrw nnoremap <buffer> m R
augroup END

" Yours. ~/.vimrc is rewritten when stage 7 runs; ~/.vimrc.local is not, and
" it is read last, so a setting there wins over the same setting above.
silent! source ~/.vimrc.local
VIMRC
    install_home_file .vimrc /tmp/vimrc.$$

    # Neovim reads init.vim, not .vimrc -- source the same file from it, so the
    # two editors never drift, and then load the Lua that vim cannot use. The
    # LSP client, the completion and the call hierarchy are Neovim-only; vim
    # keeps the editing, building and Termdebug half, which is all of it that
    # does not need a language server.
    cat > /tmp/initvim.$$ <<'INITVIM'
" Generated by copal-init.sh.
"
" THE LOAD ORDER, and it is not arbitrary. Omarchy's Neovim is LazyVim plus a
" theme layer, and lazy.nvim decides the order there. There is no plugin
" manager here, so the order is written down instead:
"
"   ~/.vimrc          the half vim also gets: options, building, Termdebug,
"                     buffers, netrw. Edit THIS for anything both editors
"                     should agree about.
"   theme.lua         the colours, and the watcher that reloads them when the
"                     desktop's theme changes underneath a running editor.
"                     First, so nothing draws in the wrong palette.
"   keys.lua          the LazyVim-shaped keys that need Lua: the pickers, the
"                     git window, the grep, and <leader> itself as a menu.
"   lsp.lua           the language servers. Last, because its keys are set
"                     per-buffer on attach and win over anything above.
"
" Each is guarded: a missing one is a feature you do not have, not an error
" on every startup.
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

" 'local' is yours: ~/.config/nvim/local.lua is never written by Copal, and
" it runs after everything else, so it wins. ~/.vimrc.local is the same
" hatch in Vimscript, read through ~/.vimrc above.
for s:f in ['theme', 'keys', 'lsp', 'local']
  let s:p = expand('~/.config/nvim/' . s:f . '.lua')
  if filereadable(s:p)
    execute 'luafile' fnameescape(s:p)
  endif
endfor
INITVIM
    install_home_file .config/nvim/init.vim /tmp/initvim.$$
    rm -f /tmp/vimrc.$$ /tmp/initvim.$$

    copal_write_themes
    dev_write_nvim_ui
    dev_write_lsp_config
    dev_write_kate_config
    dev_write_emacs_config
    dev_write_php_config
    dev_install_terminals
    dev_write_morse
    say "Typing tutor"
    add_optional gtypist@testing
    dev_write_guides
    dev_write_guides_more
    dev_write_guides_instruments

    # --- gdb ---------------------------------------------------------------
    say "Writing the gdb configuration"
    cat > /tmp/gdbinit.$$ <<'GDBINIT'
# Generated by copal-init.sh.
set confirm off
set pagination off
set print pretty on
set history save on
set history filename ~/.gdb_history
set disassembly-flavor att
# 'layout src' or Ctrl-X A gives a source view with the current line marked --
# a visual debugger without needing one.
GDBINIT
    install_home_file .gdbinit /tmp/gdbinit.$$; rm -f /tmp/gdbinit.$$

    # --- a project that proves the whole chain works -----------------------
    say "Writing a sample project at ~/dev/hello"
    cat > /tmp/main.c.$$ <<'CSRC'
#include <stdio.h>

static int accumulate(int n)
{
    int total = 0;
    for (int i = 1; i <= n; i++)
        total += i;          /* put a breakpoint here: F9 with the cursor on it */
    return total;
}

int main(void)
{
    int n = 10;
    printf("sum 1..%d = %d\n", n, accumulate(n));
    return 0;
}
CSRC
    cat > /tmp/Makefile.$$ <<'MAKEFILE'
# -g keeps the debug symbols gdb needs; -O0 stops the optimiser reordering
# lines out from under the debugger.
CC      := cc
CFLAGS  := -g -O0 -Wall -Wextra -std=c11
TARGET  := hello
SOURCES := main.c

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) -o $@ $(SOURCES)

run: $(TARGET)
	./$(TARGET)

debug: $(TARGET)
	gdb ./$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: run debug clean
MAKEFILE
    install_home_file dev/hello/main.c   /tmp/main.c.$$
    install_home_file dev/hello/Makefile /tmp/Makefile.$$
    rm -f /tmp/main.c.$$ /tmp/Makefile.$$

    dev_code_checkouts
    install_manuals

    say "Stage 7 complete."
    cat <<MSG
    Try the whole loop:

        cd ~/dev/hello
        $EDITOR_BIN main.c
        F5              build (:make -- errors land in the quickfix list)
        ]q  [q          walk the errors
        F9              breakpoint on the line under the cursor
        F4              start the debugger
        F8 / F10 / F11  continue / step over / step into
        gd  gr  K       definition / references / documentation
        \\ci            who calls this function
        Ctrl-O          back to wherever you jumped from

    Or from a shell:  make run    make debug    make clean

    THE CHECKOUTS in ~/code were cloned and then built, and what they made
    is in ~/.local/bin, which is on PATH: 'copal-build list' says what each
    one produced. birdshot is the camera -- Super+Shift+B, or Camera at the
    top of the menu. 'copal-code' pulls and rebuilds them all; 'copal-build
    NAME' rebuilds one.

    THE GUIDES. These are the tutorials, on this machine, no network needed.
    Super+Shift+G opens the list; from a terminal:

        copal-guide ide           compiling, breakpoints, stepping, call traces
        copal-guide nvim          the editor itself, from nothing to useful
        copal-guide languages     what exists on THIS board, and why
        copal-guide code          ~/code: copal-code fills it, copal-build compiles it
        copal-guide tmux          tmux and screen
        copal-guide terminals     which terminal, and why the GPU ones are not
        copal-guide instruments   bases, matrices, inverse Laplace, FFT, scopes
        copal-guide radio         software defined radio, and building your own
        copal-guide keyboard      typing tutors, and morse

    Language servers give nvim go-to-definition, references, rename, code
    actions and the call hierarchy, with no plugins installed. ':Lsp' inside
    nvim says which ones this board has.

    GUI IDEs with breakpoints, if you want menus: Geany is installed. Add
    Code::Blocks from the menu (Super+C, Devtools) -- it works on every port.
    KDevelop, Lapce and VSCodium are aarch64 only; there is no VS Code for
    ARMv6 and there will not be. 'copal-guide ide' section 6 covers this.
MSG
}
