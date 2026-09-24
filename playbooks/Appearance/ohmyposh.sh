# playbook: ohmyposh
# source:   github JanDeDobbeleer/oh-my-posh
# build:    go
# runs:
#
# program:  oh-my-posh
# label:    Oh My Posh (prompt themes)
# shelf:    Appearance
# install:  ohmyposh@source
# mode:     h
# gate:     *
# home:     https://github.com/JanDeDobbeleer/oh-my-posh
# about:    Over a hundred ready-made prompt themes for bash, zsh and fish, showing git state,
#           battery, time and more. Themes are in /usr/local/share/oh-my-posh/themes; pair it with
#           Caskaydia Cove NF.

# Oh My Posh: prompt themes for any shell, Go. Held at 30.9.0, the last
# release whose go.mod accepts Alpine 3.24's Go 1.26; 31.0 wants 1.27, and
# the alternative -- GOTOOLCHAIN fetching a newer Go -- downloads a compiler
# from outside GitHub and outside apk. The modules come from the Go
# proxy at build time into a cache inside the build directory, which goes
# when the build does. The themes are installed beside it:
#   eval "$(oh-my-posh init bash --config /usr/local/share/oh-my-posh/themes/jandedobbeleer.omp.json)"
OHMYPOSH_VER=30.9.0
ohmyposh_install() {
    _s=$(gh_source JanDeDobbeleer/oh-my-posh "v$OHMYPOSH_VER" \
         1f883716db56729bc2c97703673758892917502a81e844e2f6305067ebf968ce) || return 1
    mkdir -p "$DEST$PREFIX/bin" "$DEST$PREFIX/share/oh-my-posh"
    (cd "$_s/src" && GOPATH="$W/go" GOCACHE="$W/gocache" GOFLAGS=-modcacherw CGO_ENABLED=0 \
        go build -trimpath -o "$DEST$PREFIX/bin/oh-my-posh" \
        -ldflags "-s -w -X github.com/jandedobbeleer/oh-my-posh/src/build.Version=$OHMYPOSH_VER")
    cp -r "$_s/themes" "$DEST$PREFIX/share/oh-my-posh/"
}
