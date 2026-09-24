# command:  pdflatex
# purpose:  Typeset a LaTeX document straight to PDF.
# why:      TeX Live, for papers, theses, letters and anything with equations.
#           Stage 14 asks which: texlive, a few hundred MB, or texlive-full,
#           about 4 GB, with every package there is.
# see:      gnuplot, octave, maxima

## Use
Write the document as a `.tex` file; `pdflatex` turns it into a `.pdf`.
Cross-references, a table of contents and citations need a second run,
because the first only records where things are.

## Examples
    pdflatex paper.tex                   # paper.pdf
    pdflatex paper.tex && pdflatex paper.tex   # twice: references settle
    pdflatex -interaction=nonstopmode paper.tex   # do not stop at errors
    latexmk -pdf paper.tex               # as many runs as needed, bibliography too
    kpsewhich tikz.sty                   # is this package installed?

## Options
-interaction=nonstopmode   carry on through errors, no prompt
-halt-on-error             stop at the first error
-output-directory=DIR      write the PDF and logs there
-jobname=NAME              name the output NAME.pdf
-shell-escape              let the document run commands (minted needs it)

## Notes
- "File `tikz.sty' not found" means the package is not installed. With
  the smaller `texlive`, add a collection: `doas apk add
  texmf-dist-pictures` (TikZ), `texmf-dist-latexextra` (most others).
- At an error it waits at a `?` prompt: `x` Enter leaves. The real
  message is a few lines above, and in the `.log`.
- Keep `-shell-escape` for documents you wrote: it lets the document
  run programs.
