# command:  plantuml
# purpose:  Draw UML and other diagrams from plain text: sequence, class, state, activity, Gantt.
# why:      The catalogue's diagrams-as-text tool: a diagram kept as a few lines
#           in the repository, diffed and reviewed like code, and drawn when
#           needed.
# see:      dot, nvim

## Use
Write the diagram between `@startuml` and `@enduml` in a `.puml` file,
and run plantuml on it: a picture of the same name appears beside it.
It is a Java program, so the first run takes a few seconds.

## Examples
    printf '@startuml\nAlice -> Bob: hello\n@enduml\n' > hi.puml
    plantuml hi.puml                     # hi.png
    plantuml -tsvg hi.puml               # hi.svg instead
    plantuml --svg --output-dir out docs/   # every diagram in docs/, into out/
    cat hi.puml | plantuml -tsvg -pipe > hi.svg   # stdin to stdout
    plantuml --check-syntax docs/        # check without drawing

## Options
--svg / --png        the output format
--output-dir DIR     where the pictures go
-pipe                read stdin, write the picture to stdout
--check-syntax       check the diagrams, draw nothing
--gui                a window listing the diagrams in a folder

## Notes
- `-tsvg` and `-tpng`, the older spellings most guides use, still work.
- Class and component diagrams are laid out by Graphviz, which is
  installed (`dot`); sequence diagrams need nothing else.
- On a Pi with little memory, Java's start-up is most of the time.
  Draw a whole folder in one run rather than a file per run.
