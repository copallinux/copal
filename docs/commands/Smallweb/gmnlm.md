# command:  gmnlm
# purpose:  A line-mode Gemini browser: print a page, read its numbered links, type a number.
# why:      The catalogue's plainest Gemini client, from the gmni package: no
#           full screen, so it works in any terminal, a pipe or a slow link.
# see:      gmni, amfora, bombadillo

## Use
It prints the page, pausing at each screenful, with the links numbered.
At its prompt, a number follows a link and a few letters do the rest.

## Examples
    gmnlm gemini://geminiprotocol.net/   # open a capsule
    gmnlm -W 72 gemini://example.org/    # wrap at 72 columns

    3              (at the prompt) follow link 3
    b  f           back / forward
    m  M           save a bookmark / browse them
    |less          pipe the page into a program
    q              quit

## Options
-W WIDTH    the width to wrap at
-j MODE     trust on first use: always, once or fail
-P          no paging

## Notes
- It trusts a capsule's certificate on first use and remembers it in
  `~/.local/share/gmni/known_hosts`.
- `gmni` is its companion for scripts: one page, no browsing.
