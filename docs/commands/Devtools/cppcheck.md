# command:  cppcheck
# purpose:  Static analysis for C and C++: find bugs the compiler does not warn about.
# why:      The catalogue's C checker: out-of-bounds indexes, leaks, null
#           pointers and uninitialised variables, found by reading the code,
#           without running it.
# see:      gcc, clang, valgrind

## Use
Point it at files or a folder. By default it reports only errors it is
sure of; `--enable` widens it to warnings, style and performance.

## Examples
    cppcheck src/                        # errors only
    cppcheck --enable=all src/           # warnings, style, performance too
    cppcheck --enable=warning,performance --std=c17 src/
    cppcheck --project=compile_commands.json   # with the real flags, from bear or cmake
    cppcheck --xml src/ 2> report.xml && cppcheck-htmlreport --file=report.xml --report-dir=html

## Options
--enable=LIST       warning, style, performance, portability, all
--std=STD           the language standard: c11, c17, c++17...
--project=FILE      read files and flags from compile_commands.json
-I DIR              an include directory
--suppress=ID       silence one kind of message
-j N                use N threads
--xml               XML output, for the HTML report

## Notes
- `--enable=all` also reports `missingInclude` for system headers;
  `--suppress=missingIncludeSystem` quiets it.
- `cppcheck-gui` and `cppcheck-htmlreport` come with its optionals.
