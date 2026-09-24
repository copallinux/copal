# command:  dot
# purpose:  Graphviz: lay out and draw graphs -- boxes and arrows -- from a text description.
# why:      The catalogue's graph drawer, and the layout engine PlantUML and
#           Doxygen call. A dependency tree, a state machine or a network map
#           is a few lines of text.
# see:      plantuml, doxygen

## Use
Describe the graph in the DOT language -- nodes and `->` edges -- and
`dot` works out where everything goes and draws it. Other layouts of the
same file: `neato` and `fdp` (springs), `circo` (circles), `twopi` (rings).

## Examples
    echo 'digraph { a -> b; a -> c; b -> d }' | dot -Tsvg > g.svg   # quick
    dot -Tpng deps.dot -o deps.png       # a file, as PNG
    dot -Tpdf deps.dot -o deps.pdf       # as PDF
    neato -Tsvg net.dot -o net.svg       # the spring layout instead
    dot -Tsvg -Grankdir=LR g.dot -o g.svg   # left to right, not top down

## Options
-T FORMAT       svg, png, pdf, and others
-o FILE         the output file (default stdout)
-G NAME=VALUE   a graph attribute: rankdir=LR, bgcolor=transparent
-N NAME=VALUE   a default for every node: shape=box
-E NAME=VALUE   a default for every edge
-K LAYOUT       the layout engine: dot, neato, fdp, circo, twopi

## Notes
- `digraph` draws arrows (`->`), `graph` plain lines (`--`); mixing
  them is a syntax error.
- Large graphs are slow with `dot`; `sfdp` handles thousands of nodes.
