# command:  qpdf
# purpose:  Rewrite PDFs without changing their content: split, merge, rotate, decrypt, repair.
# why:      The catalogue's PDF surgeon. It works on the PDF's structure, not
#           its pictures, so nothing is re-rendered or lost -- and it repairs
#           files other programs refuse to open.
# see:      pdftotext

## Use
Read one PDF and write another, with pages chosen, rotated or merged on
the way. `--empty --pages` builds a new file from pages of others;
`--check` reports what is wrong with a damaged one.

## Examples
    qpdf --empty --pages a.pdf b.pdf -- both.pdf          # merge
    qpdf in.pdf --pages . 1-3 -- first3.pdf               # the first three pages
    qpdf in.pdf --pages . z-1 -- reversed.pdf             # every page, backwards
    qpdf --split-pages in.pdf out-%d.pdf                  # one file per page
    qpdf in.pdf --rotate=+90:2 out.pdf                    # rotate page 2
    qpdf --decrypt --password=secret locked.pdf open.pdf  # remove a password you know
    qpdf --check broken.pdf                               # what is wrong with it
    qpdf broken.pdf fixed.pdf                             # rewriting often repairs it

## Options
--empty              start from an empty PDF (with --pages)
--pages F R ... --   pages R of file F, in order; . is the input file
--split-pages        write each page (or group) as its own file
--rotate=[+-]DEG:R   rotate pages R
--decrypt            remove encryption (with --password)
--linearize          optimise for fast web viewing
--check              check the structure and report
--show-npages        the page count

## Notes
- Page ranges: `1-5`, `3,7,9`, `z` is the last page, `r1` counts from
  the end, `1-z:odd` every odd page.
- `--decrypt` needs the password when there is one to open it; for a
  file that opens freely but forbids printing, no password is asked.
- It never re-compresses images, so output is the same quality -- and
  roughly the same size -- as the input.
