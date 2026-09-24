# command:  doxygen
# purpose:  Generate reference documentation -- HTML, with call graphs -- from comments in source code.
# why:      The catalogue's API documenter for C, C++ and more: comments above
#           functions become a browsable site, with diagrams drawn by Graphviz.
# see:      dot, mdbook

## Use
Make a configuration file once with `-g`, set the project's name and
input folder in it, then run doxygen: the site appears in `html/`.

## Examples
    doxygen -g                           # write a Doxyfile with every setting explained
    doxygen                              # build from ./Doxyfile
    doxygen -g - | grep -E '^(INPUT|RECURSIVE) '   # the settings to look at first
    xdg-open html/index.html             # read the result

## Options
-g [FILE]    write a template configuration (default Doxyfile)
-u [FILE]    update an old configuration to this version
-s           with -g or -u: leave out the explanatory comments

## Notes
- Out of the box it documents only commented items; `EXTRACT_ALL = YES`
  in the Doxyfile lists everything.
- `HAVE_DOT = YES` turns on call and include graphs, drawn with Graphviz,
  which is installed.
- Comments it reads start with `/**` or `///`.
