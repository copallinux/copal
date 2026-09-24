# The Desktop Is the Site — plan

*copallinux.org's front door, rebuilt as the Copal desktop. Drafted 24 September 2026.*

## I. The idea

Every page of documentation the site has is now checked against the machine:
274 Terminal Guide entries, 193 man pages, 216 gallery pictures, the home page
of every program in both menus. They are reached today through a row of links
along the top of a conventional page. The desktop simulation on that page
already does most of what a front door should do, and does it the way Copal
itself does.

So the front door becomes the desktop. `index.html` is the Hyprland desktop,
full screen: the bar, the clock, the wallpaper, and the two menus. Everything
on the site opens from those menus as a window on that desktop — a program,
its guide entry, a page, a lab report.

## II. Decisions (the author's, 24 Sep 2026)

1. **The desktop is the whole site.** No conventional page beneath it.
   The current home page's text moves into a window of its own.
2. **A program's window puts its picture beside its entry.** Gallery picture
   on the left; purpose, why, use and examples on the right; the full entry,
   the man page and the project's home page linked from the title bar.
3. **Both menus, switched on the bar.** Super+A's menu by default; a bar
   button (and the key) switches to Super+Z's keyboard menu. Both open the same
   windows.

## III. What opens, and what it shows

| Chosen in the menu | Window | Content |
|---|---|---|
| A program | the program's | picture + guide entry; links: entry, man, home |
| A terminal program | foot | the entry in terminal type, the man page a click away |
| A program the guide does not cover | the program's | picture + its menu description; home page link |
| Copal ▸ a page (Install, Desktop, Platforms, Alpine, Software, Gallery) | the page's | the page itself, framed (same site) |
| Copal ▸ Terminal Guide | the guide's | commands.html, framed; a search box in the title bar |
| Copal ▸ Lab reports | the report's | the report, framed |
| Copal ▸ About (today's home text) | the welcome window | what Copal is, open at first visit |

- **Windows tile**, as Hyprland does: one fills the screen, two split it. A
  third goes to the next workspace, and the bar's 1–5 switch between them.
  This is the thing to show, not an imitation of floating windows.
- **Every window has an address.** `#gimp`, `#guide/rsync`, `#page/install`:
  shareable, bookmarkable, and the back button closes the last window opened.
- **The welcome window opens by itself** at a first visit to a bare address,
  so nobody lands on an empty desktop and has to guess.

## IV. Data

- **`docs/guide-cards.json`**, written by `copal-command-ref.py render`
  beside commands.html: for each of the 274 notes its purpose, why, use and
  examples; for the rest, the one-line purpose. Fetched on the first window
  that needs it, not on page load — commands.html is 730 kB and the cards
  should be a small fraction of that.
- **`menu-data.js`** as now (entries, pictures, home pages, both menus),
  plus the Copal section's entries.
- Pages are framed as they are; each already stands alone and keeps working
  when opened directly.

## V. What must not be lost

- **No JavaScript, a search engine, a screen reader.** `index.html` carries a
  plain list of every page and the welcome text in its HTML; the desktop is
  drawn over it. Without JavaScript the list is the page.
- **A phone.** A window is the full screen, the menu is a full-screen sheet,
  and the bar stays. Tested at 375 px wide.
- **Direct links.** `commands.html#c-rsync`, `install.html` and every other
  address keeps working unchanged.
- **Weight.** The first screen loads what the simulation loads now (the
  wallpaper, the icon sheet, menu-data.js) and nothing more.

## VI. Phases

1. **The shell.** The desktop full screen, the welcome window, windows with
   addresses, tiling and workspaces, the bar's menu switch. Pages framed.
2. **Program windows.** guide-cards.json from the generator; picture beside
   entry; the foot window for terminal programs; title-bar links.
3. **The Copal section** in both menus: pages, the guide, lab reports.
4. **Fallbacks**: no-JS list, phone layout, keyboard (Super+A, Super+Z, Esc,
   Super+Q to close), screen-reader labels.
5. **Pictures and a lab report**: headless screenshots at desktop and phone
   width, published with the change.

Each phase ends with headless-browser screenshots checked by eye and a stop
for review, as the guide's batches did.

## VII. Risks

- **A framed page inside a framed desktop** can scroll twice. Each page gets a
  `framed` mode (no site nav, no header) when opened in a window.
- **commands.html is large.** Framed only when asked for; the program windows
  never load it.
- **The simulation's code is two files written as widgets.** Phase 1 turns
  them into one desktop with two menus; the risk is regressions in edge
  scrolling and favourites, which the existing lab report's checks cover.
