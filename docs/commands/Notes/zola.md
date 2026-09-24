# command:  zola
# purpose:  A static site generator with everything built in: templates, Sass, search, link checking.
# why:      The catalogue's other site builder: one binary like Hugo, with a
#           simpler template language, and `zola check` to find dead links.
# see:      hugo, mdbook

## Use
`zola init` asks a few questions and makes the site; pages are Markdown
under `content/`, templates are Tera under `templates/`. `zola serve`
previews with live reload; `zola build` writes `public/`.

## Examples
    zola init mysite && cd mysite        # a new site, a few questions
    zola serve                           # preview at 127.0.0.1:1111
    zola build                           # build into ./public
    zola check                           # build without writing, and check every link

## Options
init DIR         create a site
serve            serve and rebuild on change
build            build into public/
check            check the site and its links
-r, --root DIR   the site's directory
-c, --config F   another config file

## Notes
- A new site has no templates: pages 404 until there is a
  `templates/index.html`, or a theme under `themes/` named in `config.toml`.
- `zola serve` listens on localhost only; `zola serve -i 0.0.0.0` to
  preview from another machine.
