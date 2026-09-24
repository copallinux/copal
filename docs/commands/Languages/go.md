# command:  go
# purpose:  The Go toolchain: build, run, test and fetch Go programs.
# why:      Stage 7 installs Go on every port, with gopls for Neovim. Several
#           of the terminal programs Copal ships are Go, and Go is the easiest
#           way to build one program for every Pi from one machine.
# see:      gdb, dlv, git, cargo

## Use
A Go project is a module: a directory with `go.mod`. `go run .` builds
and runs it, `go build` leaves a single static binary, and `go install`
builds a program from the internet into `~/go/bin`.

## Examples
    go mod init example.com/hello        # start a module here
    go run .                             # build and run it
    go build -o hello .                  # a binary called hello
    go test ./...                        # every package's tests
    go install github.com/charmbracelet/glow@latest   # a tool, into ~/go/bin
    GOOS=linux GOARCH=arm GOARM=6 go build -o hello-zero .   # for a Pi Zero
    go env GOPATH                        # where downloads and installs go

## Options
run .              build and run the package here
build -o FILE      compile to FILE
test ./...         run tests, recursively
install PKG@VER    build and install a program
mod init PATH      start a module
mod tidy           add missing and remove unused dependencies
fmt ./...          format the code (gofmt)
vet ./...          report suspicious code
env                the toolchain's settings; GOOS, GOARCH, GOARM, CGO_ENABLED

## Notes
- Cross-compiling is the trick: set `GOOS`, `GOARCH` (arm64, arm,
  amd64) and for 32-bit ARM `GOARM` (6 for a Zero, 7 for a Pi 2), and the
  binary runs there -- as long as `CGO_ENABLED=0` or no C is involved.
- `~/go/bin` is on PATH on a Copal machine; Alpine alone does not put it there.
- A program that uses C through cgo needs gcc and links against musl;
  such a binary will not run on a glibc system.
