# command:  pdftotext
# purpose:  Pull the text out of a PDF -- and, with the other poppler tools, split, join and inspect PDFs.
# why:      The catalogue's PDF toolkit (poppler-utils): search a PDF with grep,
#           read one over SSH, or feed it to a script. Its siblings pdfinfo,
#           pdfunite, pdfseparate and pdftoppm come in the same package.
# see:      qpdf, tesseract

## Use
`pdftotext FILE.pdf` writes `FILE.txt`; with `-` as the output it prints
to the terminal. `-layout` keeps columns and tables where they were,
instead of reflowing the text.

## Examples
    pdftotext paper.pdf                  # paper.txt beside it
    pdftotext -layout invoice.pdf -      # to the terminal, columns kept
    pdftotext -f 3 -l 5 book.pdf part.txt   # pages 3 to 5 only
    pdftotext paper.pdf - | grep -i copal   # search inside a PDF
    pdfinfo paper.pdf                    # pages, size, author, producer
    pdfunite a.pdf b.pdf both.pdf        # join
    pdfseparate book.pdf page-%d.pdf     # one file per page
    pdftoppm -png -r 150 paper.pdf page  # pages as PNG pictures

## Options
-layout        keep the physical layout: columns, tables
-f N  -l N     the first and last page
-raw           the text in the order it is stored
-enc UTF-8     the output encoding
-nopgbrk       no form feed between pages
-              as the output file: stdout

## Notes
- A scanned PDF is pictures of pages and has no text to extract: the
  output is empty. Run the pages through `tesseract` (from `pdftoppm`'s
  images) to get text.
- Multi-column papers come out interleaved without `-layout`, and
  hyphenated at line ends either way.
