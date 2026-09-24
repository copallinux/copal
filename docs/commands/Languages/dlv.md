# command:  dlv
# purpose:  Delve: the debugger for Go -- breakpoints, stepping, goroutines.
# why:      The catalogue's Go debugger. gdb can step through Go but does not
#           understand goroutines, interfaces or Go's types; Delve does.
# see:      go, gdb

## Use
`dlv debug` builds the package in the current folder with debugging on
and stops before `main`. Set breakpoints, continue, and look around at
the `(dlv)` prompt.

## Examples
    dlv debug                            # build and debug the package here
    dlv debug -- -v input.txt            # with arguments for the program
    dlv test                             # debug the package's tests
    dlv exec ./server                    # a binary built already
    doas dlv attach $(pidof server)      # a running process

    break main.main     (at the prompt) a breakpoint; b file.go:42 for a line
    continue            run to it (c)
    next / step         over / into
    print x             a value (p)
    goroutines          every goroutine;  exit  leave

## Options
debug [PKG]      build and debug
test [PKG]       debug the tests
exec BINARY      debug a built binary
attach PID       attach to a running process
core BIN CORE    examine a core dump

## Notes
- 64-bit only: its catalogue row is gated to aarch64 and x86_64.
- Build with optimisations off to follow the source line by line: `dlv
  debug` does this for you; for `exec`, build with
  `go build -gcflags=all="-N -l"`.
