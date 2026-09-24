# command:  hugo
# purpose:  A static site generator: Markdown and templates in, a whole website out, fast.
# why:      The catalogue's site builder for a blog, a wiki or a project page:
#           one binary, no runtime, and a site of thousands of pages in seconds.
# see:      zola, mdbook

## Use
Make a site, add a theme, write content as Markdown under `content/`,
and preview with `hugo server`. `hugo` alone builds the finished site into
`public/`.

## Examples
    hugo new site mysite && cd mysite    # a new site
    hugo new content posts/first.md      # a page, as a draft
    hugo server -D                       # preview at localhost:1313, drafts included
    hugo                                 # build into ./public
    hugo --minify                        # smaller output

## Options
new site DIR        create a site
new content PATH    create a page from its archetype
server              serve and rebuild on change; -D includes drafts
-D, --buildDrafts   include drafts
--minify            minify the HTML, CSS and JS
-d, --destination DIR  build somewhere other than public/

## Notes
- A new site has no theme, and builds blank pages: add one under
  `themes/` and name it in `hugo.toml` (`theme = "name"`).
- Pages made with `hugo new` start as drafts (`draft = true`) and are
  left out of a build until that line changes, or `-D` is given.
