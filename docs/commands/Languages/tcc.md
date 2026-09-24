# command:  tcc
# purpose:  The Tiny C Compiler: compiles C almost instantly, and can run a C file as a script.
# why:      The catalogue's fastest C compiler: for trying an idea, or running
#           C like a script, on a board where gcc takes its time.
# see:      gcc, clang

## Use
Compile as with gcc, or `tcc -run file.c` to compile and run in one go,
in memory. It optimises little: for speed of compiling, not of the
program.

## Examples
    tcc -run hello.c                     # compile and run, no file left behind
    tcc -run prog.c arg1 arg2            # with arguments for the program
    tcc -o hello hello.c                 # an executable
    echo 'int main(){return 42;}' | tcc -run -   # from stdin

## Options
-run          compile and run at once
-o FILE       the output
-c            compile to an object file
-g            debug information
-Wall         warnings
-I DIR        a header directory;  -L DIR -lNAME  libraries

## Notes
- A file starting `#!/usr/bin/tcc -run` can be made executable and run
  directly, like a shell script.
- It supports C99 and most of C11; code leaning on GCC extensions may
  not compile.
