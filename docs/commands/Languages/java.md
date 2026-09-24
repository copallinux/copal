# command:  java
# purpose:  OpenJDK 21: run Java programs, and with javac and jshell, write them.
# why:      The catalogue's Java, on the 64-bit boards: for the programs that
#           ship as a .jar, and for learning or writing Java itself.
# see:      plantuml

## Use
`java File.java` compiles and runs a single-file program at once.
`javac` compiles, `java -jar` runs a packaged program, and `jshell` is an
interactive prompt.

## Examples
    java Hello.java                      # compile and run one file
    javac Hello.java && java Hello       # compile, then run the class
    java -jar program.jar                # a packaged program
    jshell                               # try Java a line at a time; /exit leaves
    java -Xmx256m -jar program.jar       # cap its memory on a small board

## Options
-jar FILE       run a packaged program
-cp PATH        where to find classes and jars
-Xmx SIZE       the most heap it may use: -Xmx256m
-version        the version (to stderr)

## Notes
- On a Pi with little memory, `-Xmx` keeps a program from taking all of
  it; Java's default is a quarter of RAM.
- 64-bit only: its catalogue row is gated to aarch64 and x86_64.
