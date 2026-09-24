# command:  tesseract
# purpose:  OCR: read the text in a picture of a page, and write it as text or a searchable PDF.
# why:      The catalogue's optical character recogniser, with English. It turns
#           scans and screenshots into text you can search, copy and edit.
# see:      pdftotext, copal-shot

## Use
Give it an image and an output name: it writes NAME.txt. Put `-` as the
name for the terminal, and add `pdf` at the end for a PDF with the text
under the picture. Clean, straight, 300 dpi scans read best.

## Examples
    tesseract scan.png out               # out.txt
    tesseract scan.png - | less          # to the terminal
    tesseract scan.png out pdf           # out.pdf, searchable
    tesseract photo.jpg - --psm 6        # one block of text: signs, labels
    pdftoppm -r 300 -png scan.pdf pg && for f in pg-*.png; do tesseract $f - ; done > scan.txt
    tesseract --list-langs               # the languages installed

## Options
-l LANG[+LANG]   the language(s): eng, or eng+deu
--psm N          page segmentation: 3 automatic, 6 one block, 7 one line
--dpi N          the resolution, when the image does not say
--list-langs     the installed languages
pdf / hocr / tsv the output formats, named after the output base

## Notes
- It needs a language's data to do anything: "Failed loading language
  'eng'" means `tesseract-ocr-data-eng` is missing. Copal installs it with
  the catalogue row from 24 Sep 2026; before that, `doas apk add
  tesseract-ocr-data-eng`. Other languages are `tesseract-ocr-data-deu`
  and so on.
- A photo at an angle or in low light reads badly: crop, straighten and
  raise the contrast first.
- Not on the 32-bit Pis (armv6, armhf): the row is gated off there.
