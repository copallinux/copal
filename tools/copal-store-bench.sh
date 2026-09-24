#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-store-bench.sh -- run a copal-store recipe on the bench, without root.
#
#   tools/copal-store-bench.sh RECIPE          build and install it under the bench prefix
#   tools/copal-store-bench.sh run RECIPE CMD  run CMD with the bench prefix and sysroot on the paths
#   tools/copal-store-bench.sh env             print the environment, to eval in a shell
#   tools/copal-store-bench.sh remove RECIPE   the store's own remove, against the bench prefix
#
# THE SAME RECIPE THE CARD RUNS. This does not copy any of it: it runs
# tools/copal-store's own install code with its paths pointed into
# ~/.cache/copal-store and apk switched off (COPAL_STORE_NODEPS=1). What apk
# would have installed is fetched with 'apk fetch' -- no root needed -- and
# unpacked into a sysroot there instead, the way wxMaxima was first built
# (docs/integration-lab-report.md, B).
#
# THE SYSROOT. Dev packages carry headers, .pc files and the unversioned
# library link; the library itself is already in /usr/lib when its runtime
# package is installed, which on this bench it nearly always is. So after
# unpacking, the .pc files are re-prefixed to the sysroot and every library
# link the sysroot cannot resolve is aimed at /usr/lib -- versioned names
# too, because CMake's imported targets name libX.so.6.11.1, not libX.so. A
# runtime package that is NOT installed is unpacked the same way, and
# LD_LIBRARY_PATH finds it.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
B="$HOME/.cache/copal-store"
R="$B/sysroot"

export COPAL_STORE_PREFIX="$B/prefix"
export COPAL_STORE_STATE="$B/state"
export COPAL_STORE_CACHE="$B/cache"
export COPAL_STORE_WORK="$B/work"
export COPAL_STORE_LOGDIR="$B/logs"
export COPAL_EVENTS="$B/events"
export COPAL_STORE_NODEPS=1
# A failed build's tree is kept here to look inside; on a machine it is
# removed, and the summary and the compressed log are the record.
export COPAL_STORE_KEEP_WORK=1
export PKG_CONFIG_PATH="$R/usr/lib/pkgconfig:$R/usr/share/pkgconfig:$COPAL_STORE_PREFIX/lib/pkgconfig"
export CMAKE_PREFIX_PATH="$R/usr"
export QT_ADDITIONAL_PACKAGES_PREFIX_PATH="$R/usr"
# SDL's add-on libraries put their headers in include/SDL2 and include
# <SDL.h> from beside them; sdl2-config names only the real /usr/include/SDL2.
export CPATH="$R/usr/include:$R/usr/include/SDL2:/usr/include/SDL2"
export LIBRARY_PATH="$R/usr/lib"
export LD_LIBRARY_PATH="$COPAL_STORE_PREFIX/lib:$R/usr/lib"
export PATH="$COPAL_STORE_PREFIX/bin:$R/usr/bin:$PATH"
# Python programs unpacked into the sysroot (scons, meson modules) need their
# packages found there too.
_pyv=$(python3 -c 'import sys; print("python%d.%d" % sys.version_info[:2])' 2>/dev/null || echo python3)
export PYTHONPATH="$R/usr/lib/$_pyv/site-packages:$R/usr/lib/$_pyv:$R/usr/lib/$_pyv/lib-dynload${PYTHONPATH:+:$PYTHONPATH}"

sysroot_add() {  # <apk names...> -- with their dependencies, only what is not installed
    mkdir -p "$R" "$B/apks"
    # A package installed for real since it was unpacked here supersedes the
    # copy: CMAKE_PREFIX_PATH and PKG_CONFIG_PATH search the sysroot first,
    # so its stale files would be found instead. Seen with Qt 6 Multimedia,
    # whose sysroot CMake package named a plugin the sysroot never had.
    for _d in "$R"/usr/lib/cmake/*/; do
        [ -d "/usr/lib/cmake/$(basename "$_d")" ] && rm -rf "$_d"
    done
    for _f in "$R"/usr/lib/pkgconfig/*.pc; do
        [ -e "/usr/lib/pkgconfig/${_f##*/}" ] && rm -f "$_f"
    done
    for _t in "$@"; do
        _p=${_t%@testing}
        apk info -e "$_p" >/dev/null 2>&1 && continue
        # --recursive, as apk add would resolve them: py3-pexpect is no use
        # without py3-ptyprocess. With -R, a package from edge/testing has
        # to be named with its tag, as the recipe writes it. Fetched into a
        # directory of its own, and only the ones this machine does not
        # already have are unpacked.
        # -R fetches the installed dependencies too -- 1.4 GB of them after
        # nineteen recipes filled the bench's disk -- so each download is
        # deleted once unpacked, and a marker stops a second fetch.
        _dd="$B/apks/$_p"; mkdir -p "$_dd"
        [ -e "$_dd/.unpacked" ] && continue
        (cd "$_dd" && apk fetch -q -R "$_t" >/dev/null 2>&1)
        ls "$_dd"/*.apk >/dev/null 2>&1 || { echo "bench: apk fetch $_t failed" >&2; continue; }
        for _f in "$_dd"/*.apk; do
            _n=$(tar -xzOf "$_f" .PKGINFO 2>/dev/null | sed -n 's/^pkgname = //p')
            [ -n "$_n" ] && apk info -e "$_n" >/dev/null 2>&1 && continue
            tar -xzf "$_f" -C "$R" --exclude='.PKGINFO' --exclude='.SIGN*' \
                --exclude='.pre-*' --exclude='.post-*' --exclude='.trigger' 2>/dev/null || true
            echo "  sysroot + ${_f##*/}"
        done
        rm -f "$_dd"/*.apk; : > "$_dd/.unpacked"
    done
    find "$R" -name '*.pc' -exec sed -i \
        -e "s|^prefix=/usr\$|prefix=$R/usr|" -e "s|^libdir=/usr/lib|libdir=$R/usr/lib|" \
        -e "s|^includedir=/usr/include|includedir=$R/usr/include|" {} + 2>/dev/null || true
    [ -d "$R/usr/lib" ] || return 0
    for _l in "$R"/usr/lib/*.so*; do
        [ -L "$_l" ] || continue
        _t=$(readlink "$_l"); case "$_t" in /*) continue ;; esac
        [ -e "$R/usr/lib/$_t" ] || { [ -e "/usr/lib/$_t" ] && ln -sfn "/usr/lib/$_t" "$_l"; }
    done
    for _l in "$R"/usr/lib/lib*.so; do
        [ -e "$_l" ] || [ -L "$_l" ] || continue
        _n=${_l##*/}
        for _v in /usr/lib/"$_n".*; do
            [ -e "$_v" ] && [ ! -e "$R/usr/lib/${_v##*/}" ] && ln -s "$_v" "$R/usr/lib/${_v##*/}"
        done
    done
    # A link one directory down, aimed back up: lua5.4-dev's lua5.4/liblua.so
    # is ../liblua-5.4.so.0. Left dangling, the linker quietly takes the
    # static liblua.a beside it, which is not position-independent, and a
    # shared object (darktable's) fails to link.
    for _l in "$R"/usr/lib/*/lib*.so; do
        [ -L "$_l" ] && [ ! -e "$_l" ] || continue
        _t=$(readlink "$_l"); _sub=${_l%/*}; _sub=${_sub##*/}
        case "$_t" in /*) _abs="$_t" ;; *) _abs=$(realpath -m "/usr/lib/$_sub/$_t") ;; esac
        [ -e "$_abs" ] && ln -sfn "$_abs" "$_l"
    done
    # A dev package newer than the installed library: libheif-dev 1.23.4's
    # CMake file names libheif.so.1.23.4 while the machine has 1.23.0. On a
    # card apk would upgrade the library with it; here the name is aimed at
    # the installed library of the same soname, which is ABI-compatible by
    # that soname's promise.
    grep -rhoE "\\\$\\{_IMPORT_PREFIX\\}/lib/lib[A-Za-z0-9_+-]+\\.so\\.[0-9.]+|$R/usr/lib/lib[A-Za-z0-9_+-]+\\.so\\.[0-9.]+" \
        "$R"/usr/lib/cmake 2>/dev/null | sed 's|.*/||' | sort -u | while read -r _f; do
        [ -e "$R/usr/lib/$_f" ] && continue
        _so=$(printf '%s' "$_f" | sed 's/^\(lib[^.]*\.so\.[0-9]*\).*/\1/')
        [ -e "/usr/lib/$_so" ] && ln -sfn "$(realpath "/usr/lib/$_so")" "$R/usr/lib/$_f"
    done
    return 0
}

STORE="$REPO/tools/copal-store"
case "${1:-}" in
    env)
        for _v in COPAL_STORE_PREFIX COPAL_STORE_STATE COPAL_STORE_CACHE COPAL_STORE_WORK \
                  COPAL_STORE_LOGDIR COPAL_STORE_NODEPS PKG_CONFIG_PATH CMAKE_PREFIX_PATH \
                  QT_ADDITIONAL_PACKAGES_PREFIX_PATH CPATH LIBRARY_PATH LD_LIBRARY_PATH PATH; do
            eval "printf 'export %s=\"%s\"\n' $_v \"\$$_v\""
        done ;;
    run)    shift; shift; exec "$@" ;;
    remove) exec "$STORE" remove "$2" ;;
    ''|-h|--help) sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)
        _r="$1"
        _d=$("$STORE" deps "$_r")
        # shellcheck disable=SC2046
        sysroot_add $(printf '%s\n' "$_d" | sed 's/^[a-z]*: //')
        exec "$STORE" install "$_r"
        ;;
esac
