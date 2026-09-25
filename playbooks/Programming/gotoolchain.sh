# playbook: gotoolchain
# source:   url go.dev
# build:
# runs:
#
# program:  -
# label:    Go (upstream, go.dev)
# shelf:    Programming
# install:  gotoolchain@source
# mode:     h
# gate:     *
# home:     https://go.dev
# about:    The newest Go, as the Go project releases it: go and gofmt in /usr/local, ahead of
#           Alpine's go on PATH. For modules that want a newer Go than Alpine carries.

# Go, upstream: the release archive from go.dev, the file for this machine's
# architecture at a pinned version and checksum. The Go project builds its
# tools statically, so they run on musl as they are -- checked on the bench,
# along with cgo through Alpine's gcc. Installed whole into $PREFIX/lib/go,
# with go and gofmt linked into $PREFIX/bin: /usr/local/bin comes before
# /usr/bin on PATH, so this go answers ahead of Alpine's (the 'go' entry),
# and removing it hands the name back.
#
# WHY IT IS HERE. Alpine carries one Go release behind, and builds it with
# GOTOOLCHAIN=local; a module that asks for the newer one -- Gonex does --
# then has its compiler downloaded into ~/go at build time, outside apk and
# outside this shelf. With this installed, nothing is downloaded: the go that
# answers is new enough. It keeps upstream's own GOTOOLCHAIN=auto.
GOTOOLCHAIN_VER=1.27.1
gotoolchain_install() {
    case "$(apk --print-arch 2>/dev/null)" in
        aarch64) _a=arm64  _sum=3450b45a3f9ee8568792736a5c5e70a1f2e9b36c35a8f74958c03e51d7d92bec ;;
        x86_64)  _a=amd64  _sum=63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445 ;;
        armv7|armhf) _a=armv6l _sum=44893f200fb034791d4188df9fc9b9e73eadbb5fceafd5166703f0b9bab73fc2 ;;
        x86)     _a=386    _sum=3b72028095439d2bc0ce84e271cc70328a878d879020c5721eaa46df5f72fbc0 ;;
        *) echo "go.dev has no build for $(apk --print-arch)"; return 1 ;;
    esac
    _f=$(url_asset "https://go.dev/dl/go$GOTOOLCHAIN_VER.linux-$_a.tar.gz" "$_sum") || return 1
    mkdir -p "$DEST$PREFIX/lib" "$DEST$PREFIX/bin"
    tar -xzf "$_f" -C "$DEST$PREFIX/lib" || return 1
    ln -sf ../lib/go/bin/go "$DEST$PREFIX/bin/go"
    ln -sf ../lib/go/bin/gofmt "$DEST$PREFIX/bin/gofmt"
}
