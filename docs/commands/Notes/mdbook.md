# command:  mdbook
# purpose:  Write a book as Markdown files and build it into a website.
# why:      The catalogue's tool for long-form documentation -- the Rust book is
#           made with it. A folder of Markdown and a table of contents become a
#           searchable site that works offline.
# see:      hugo, zola, nvim

## Use
`mdbook init` makes the skeleton: `book.toml` and `src/`, with
`src/SUMMARY.md` as the table of contents. Write chapters as Markdown,
list them in the summary, and `mdbook serve` shows the book in a browser,
rebuilding as you save.

## Examples
    mdbook init mybook                   # a new book, in ./mybook
    cd mybook && mdbook serve --open     # write, with a live preview
    mdbook build                         # the site, into ./book
    mdbook clean                         # remove the built site

## Options
init [DIR]          create a book
build               build it, into book/
serve [--open]      serve on localhost:3000, rebuild on change; open the browser
watch               rebuild on change, no server
clean               delete the build

## Notes
- A chapter that is not listed in `src/SUMMARY.md` is not in the book.
  Adding a line there that names a missing file creates the file.
- The built `book/` folder is the whole site: copy it to any web
  server, or open `book/index.html` from disk.
