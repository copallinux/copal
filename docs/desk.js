/* The desktop on the site's front page (docs/splash-plan.md).
 *
 * index.html is a page, and in it, a panel wide as the screen, is Copal's
 * Hyprland desktop, live: the bar, the clock, the wallpaper, and the two menus
 * -- copal-gui (menu-gui.js) and copal-menu (menu-keys.js). When the panel
 * scrolls into view copal-gui opens by itself on a program with a picture,
 * gold arrows say what to do, and the bar's two menu buttons glow until one is
 * used. The bar's last button makes the desktop the whole screen, and back.
 * Everything on the site opens from the menus as a window:
 *
 *   #page/NAME   a page of the site, framed: about, install, commands ...
 *   #app/CMD     a program: its gallery picture beside its Terminal Guide
 *                entry, the full entry, man page and home page a click away
 *   #man/CMD     a man page, framed
 *
 * Windows tile the way Hyprland tiles them. One fills the workspace, two
 * split it, and a third goes to the next workspace with room, which the bar's
 * 1-5 then show; on a narrow screen a workspace holds one. Every window has an
 * address, so it can be shared, and opening one is a step in the browser's
 * history: Back closes it again.
 *
 * An address opens straight into the full-screen desktop with that window.
 * Without JavaScript none of this runs: the panel shows a picture of the
 * desktop, and the page around it is the page.
 */
(function () {
  "use strict";
  var D = window.COPAL_MENU;
  var root = document.getElementById("desk");
  if (!D || !root || !window.CopalMenus) return;
  // Inside a window of the desktop -- this page framed as About Copal -- there
  // is no second desktop: site.css hides the panel in a framed page.
  if (window.self !== window.top) return;

  var WORKSPACES = 5;
  // The pages a window may frame: the site's own, by file stem, as the menus'
  // Copal section lists them (tools/copal-menu-sim.py's SITE). Nothing else is
  // framed, so an address cannot put another site inside this one.
  var PAGES = {};
  (D.pages || []).forEach(function (p) { PAGES[p.page] = p.title; });

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  // ----- what a program is, from the menus' data -----
  var refs = D.refs || {}, homes = D.homes || {};
  var gallery = {}, site = {}, byCmd = {};
  (D.gallery || []).forEach(function (g) { gallery[g] = 1; });
  (D.site || []).forEach(function (g) { site[g] = 1; });
  (D.apps || []).forEach(function (a) {
    [a.prog, a.exec].forEach(function (c) { if (c && !byCmd[c]) byCmd[c] = a; });
  });
  function shot(cmd) {
    var a = byCmd[cmd], s = (a && a.shot) || (gallery[cmd] ? cmd : null);
    if (a && a.big) return "img/site/" + a.big + ".jpg";
    if (!s) return null;
    return (site[s] ? "img/site/" : "img/gallery/") + s + ".jpg";
  }

  // The Terminal Guide's entries (guide-cards.json, written by
  // copal-command-ref.py render beside commands.html): fetched once, by the
  // first program window, never on page load.
  var cards = null, cardsWait = null;
  function withCards(then) {
    if (cards) { then(cards); return; }
    if (!cardsWait) {
      // Stamped by tools/copal-stamp.py, so a changed file is a new address.
      var v = root.getAttribute("data-cards");
      cardsWait = fetch("guide-cards.json" + (v ? "?v=" + v : "")).then(function (r) { return r.ok ? r.json() : {}; })
        .catch(function () { return {}; })
        .then(function (c) { cards = c; return c; });
    }
    cardsWait.then(then);
  }

  // `code` in an entry's text becomes code, and a link to that program's
  // window when it names one the guide knows.
  function prose(tag, text) {
    var e = el(tag);
    String(text).split(/(`[^`]+`)/).forEach(function (part) {
      if (!/^`[^`]+`$/.test(part)) { e.appendChild(document.createTextNode(part)); return; }
      var t = part.slice(1, -1), w = t.split(/\s/)[0];
      var c = el("code", null, t);
      if (cards && cards[w] && t === w) { var a = el("a"); a.href = "#app/" + w; a.appendChild(c); e.appendChild(a); }
      else e.appendChild(c);
    });
    return e;
  }

  // ----- the desktop -----
  root.textContent = "";          // the picture that stands in without JavaScript
  root.className = "desk";
  root.style.backgroundImage = "url(img/menu/wallpaper.jpg)";
  root.setAttribute("role", "application");
  root.setAttribute("aria-label", "The Copal desktop. Its menus open every page of the site as a window.");

  var bar = el("div", "sim-bar");
  bar.setAttribute("role", "toolbar");
  bar.setAttribute("aria-label", "The bar: menus and workspaces");
  var bGui = el("button", "desk-menu", "≡");
  bGui.title = "Applications — copal-gui (Ctrl+Alt+A; Super+A on a Copal machine)";
  bGui.setAttribute("aria-label", bGui.title);
  var bKeys = el("button", "desk-menu keys", "❯_");
  bKeys.title = "copal-menu (Ctrl+Alt+Space; Ctrl+Alt+Z for its System pane)";
  bKeys.setAttribute("aria-label", bKeys.title);
  var wsBox = el("div", "sim-ws");
  var wsTabs = [];
  for (var n = 1; n <= WORKSPACES; n++) {
    (function (n) {
      var s = el("span", "", String(n));
      s.setAttribute("role", "button");
      s.tabIndex = 0;
      s.title = "Workspace " + n + " (Ctrl+Alt+" + n + ")";
      s.setAttribute("aria-label", "Workspace " + n);
      s.addEventListener("click", function (e) { e.stopPropagation(); showWorkspace(n); });
      s.addEventListener("keydown", function (e) {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); showWorkspace(n); }
      });
      wsBox.appendChild(s); wsTabs.push(s);
    })(n);
  }
  var title = el("span", "grow", "");
  var stat = el("span", "stat", "c12%  m19%  d48%   eth up");
  var tbar = el("span", "time", "");
  // Four corners, drawn: the fonts on the page have no full-screen sign.
  var bFull = el("button", "desk-menu full");
  bFull.innerHTML = '<svg width="14" height="14" viewBox="0 0 14 14" aria-hidden="true"><path d="M1 5V1h4M9 1h4v4M13 9v4H9M5 13H1V9" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>';
  [bGui, bKeys, wsBox, title, stat, tbar, bFull].forEach(function (x) { bar.appendChild(x); });
  root.appendChild(bar);

  var clock = el("div", "sim-clock");
  var hm = el("div", "hm"), dt = el("div", "date");
  clock.appendChild(hm); clock.appendChild(dt);
  root.appendChild(clock);
  function tick() {
    var d = new Date();
    var t = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
    hm.textContent = t; tbar.textContent = t;
    dt.textContent = d.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
  }
  tick(); setInterval(tick, 10000);

  var tiles = el("div", "desk-tiles");
  root.appendChild(tiles);
  var spaces = [];
  for (var w = 0; w < WORKSPACES; w++) {
    var sp = el("div", "desk-ws");
    sp.hidden = true;
    tiles.appendChild(sp); spaces.push(sp);
  }

  // ----- the menus -----
  var desk = {
    // A page of the site, or a program.
    launch: function (item) { if (item.page) open("page/" + item.page); else open(appRoute(item.cmd), item); },
    clock: function () { return hm.textContent; },
    shot: shot
  };
  var gui = window.CopalMenus.gui(D, root, desk);
  var keys = window.CopalMenus.keys(D, root, desk);
  function closeMenus() { gui.close(); keys.close(); }
  bGui.addEventListener("click", function (e) { e.stopPropagation(); keys.close(); gui.toggle(); });
  bKeys.addEventListener("click", function (e) { e.stopPropagation(); gui.close(); keys.toggle(); });

  // ----- the whole screen, and back -----
  // back: leaving by the button, so the panel is where the reader is left.
  function setFull(on, back) {
    root.classList.toggle("full", on);
    document.documentElement.classList.toggle("desk-full", on);
    bFull.title = on ? "Back to the page" : "The whole screen";
    bFull.setAttribute("aria-label", bFull.title);
    bFull.setAttribute("aria-pressed", on ? "true" : "false");
    if (!on && back) root.scrollIntoView({ block: "center" });
  }
  bFull.addEventListener("click", function (e) { e.stopPropagation(); setFull(!root.classList.contains("full"), true); });

  // ----- the cues: what to do, until something is done -----
  // Gold arrows with a few words each, pointing at the open menu, its Copal
  // section, and the bar's keyboard-menu button; and a glow on the bar's two
  // menu buttons. All of it goes at the first click or key in the desktop.
  // Beside the menu, pointing left at it, under the picture card; placed from
  // where the menu and the card actually are. Where there is no room beside
  // the menu (a phone, where it fills the panel) only the bar's line stays.
  var LEFT = '<svg viewBox="0 0 48 24" aria-hidden="true"><path d="M46 12 C32 5 18 5 4 12 M4 12 l8 -6 M4 12 l8 6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>';
  var UP = '<svg viewBox="0 0 24 40" aria-hidden="true"><path d="M12 38 C7 27 7 16 12 4 M12 4 l-6 8 M12 4 l6 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>';
  var cues = el("div", "desk-cues");
  cues.setAttribute("aria-hidden", "true");
  var cue = {};
  [["pick", "pick a program: its picture, its guide entry", LEFT],
   ["site", "this site's pages are under Copal", LEFT],
   ["full", "the whole screen", UP]].forEach(function (c) {
    var q = el("div", "cue " + c[0]);
    q.innerHTML = c[2];
    q.appendChild(el("span", null, c[1]));
    cues.appendChild(q); cue[c[0]] = q;
  });
  root.appendChild(cues);
  function placeCues() {
    var r = root.getBoundingClientRect();
    var m = gui.el.getBoundingClientRect();
    var peek = root.querySelector(".sim-peek.on");
    var pk = peek && peek.offsetParent ? peek.getBoundingClientRect() : null;
    var fb = bFull.getBoundingClientRect();
    var x = m.right - r.left + 10;
    var y = pk ? pk.bottom - r.top + 18 : (m.top - r.top) + m.height * 0.45;
    var room = !gui.el.hidden && r.right - m.right > 250 && y + 110 < r.height;
    cue.pick.style.left = cue.site.style.left = x + "px";
    cue.pick.style.top = y + "px";
    cue.site.style.top = (y + 56) + "px";
    cue.pick.hidden = cue.site.hidden = !room;
    cue.full.style.right = (r.right - fb.right + 2) + "px"; cue.full.style.top = "30px";
    cue.full.hidden = r.width < 760;    // on a phone it would sit on the search
  }
  function showCues() {
    placeCues();
    cues.classList.add("on");
    title.textContent = "← ≡ and ❯_: the two menus";
    title.classList.add("hint");
  }
  window.addEventListener("resize", function () { if (cues.classList.contains("on")) placeCues(); });
  [bGui, bKeys].forEach(function (b) { b.classList.add("pulse"); });
  var started = false;
  function start() {
    if (started) return;
    started = true;
    cues.classList.remove("on");
    title.classList.remove("hint");
    if (title.textContent.charAt(0) === "←") title.textContent = "";
    [bGui, bKeys].forEach(function (b) { b.classList.remove("pulse"); });
  }
  root.addEventListener("pointerdown", start, true);
  root.addEventListener("keydown", start, true);

  // Open by itself the first time the panel is well in view, on a starter
  // favourite with a picture -- unless the visitor has already begun.
  var PICK = { section: "Favourites", pick: "firefox-esr.desktop", quiet: true };
  function arrive() {
    if (started || wins.length || gui.isOpen() || keys.isOpen()) return;
    gui.open(PICK);
    showCues();
  }
  // The layer-shell backdrop: a click that misses a menu closes it.
  // A click on the desktop itself -- the wallpaper, between windows -- closes
  // an open menu, or else a program's details, as a click anywhere does.
  root.addEventListener("click", function () {
    if (gui.isOpen() || keys.isOpen()) closeMenus();
    else dismissDetails(true);
  });
  root.addEventListener("contextmenu", function (e) { if (e.target === root || e.target === tiles) e.preventDefault(); });

  // ----- windows -----
  var wins = [];          // every open window, oldest first
  var current = 1;        // the workspace on screen
  var focused = null;

  function perWorkspace() { return root.clientWidth < 760 ? 1 : 2; }
  function onSpace(n) { return wins.filter(function (x) { return x.ws === n; }); }

  function showWorkspace(n) {
    current = n;
    spaces.forEach(function (s, i) { s.hidden = i !== n - 1; });
    var here = onSpace(n);
    focus(here.length ? here[here.length - 1] : null, true);
    paintBar();
  }
  function paintBar() {
    wsTabs.forEach(function (t, i) {
      var used = onSpace(i + 1).length;
      t.className = (i + 1 === current ? "on" : "") + (used ? " used" : "");
      t.setAttribute("aria-current", i + 1 === current ? "true" : "false");
      t.setAttribute("aria-label", "Workspace " + (i + 1) + (used ? ", " + used + (used > 1 ? " windows" : " window") : ", empty"));
    });
    title.textContent = focused ? focused.title : "";
  }
  function focus(x, quiet) {
    wins.forEach(function (y) { y.el.classList.toggle("focus", y === x); });
    focused = x;
    if (x && x.ws !== current) { showWorkspace(x.ws); return; }
    if (x && !quiet && location.hash !== "#" + x.route) history.replaceState(null, "", "#" + x.route);
    // The keyboard, and a screen reader, follow the window with focus -- but
    // never out of an open menu's field.
    if (x && !quiet && !gui.isOpen() && !keys.isOpen() && !x.el.contains(document.activeElement)) x.el.focus({ preventScroll: true });
    paintBar();
  }
  // Where a new window goes: here if there is room, else the next workspace
  // that has some, else here in place of the oldest.
  function placeFor() {
    var cap = perWorkspace();
    for (var k = 0; k < WORKSPACES; k++) {
      var n = ((current - 1 + k) % WORKSPACES) + 1;
      if (onSpace(n).length < cap) return n;
    }
    close(onSpace(current)[0], true);
    return current;
  }

  function frame(x, route) {
    x.el.classList.add("page");
    var f = el("iframe");
    f.title = x.title;
    f.src = route.file;
    f.addEventListener("load", function () {
      var doc;
      try { doc = f.contentDocument; } catch (e) { doc = null; }
      if (!doc) return;
      doc.documentElement.classList.add("framed");
      var t = (doc.title || "").replace(/ · Copal Linux$/, "");
      if (t) { x.title = t; x.name.textContent = t; paintBar(); }
      // A link to another page of the site opens it as a window of its own;
      // a link off the site opens a tab, as it would from the page itself.
      doc.addEventListener("click", function (e) {
        var a = e.target.closest && e.target.closest("a[href]");
        if (!a || e.defaultPrevented || e.button !== 0 || e.ctrlKey || e.metaKey || e.shiftKey) return;
        var u = new URL(a.getAttribute("href"), doc.baseURI);
        if (u.origin !== location.origin) { a.target = "_blank"; a.rel = "noopener"; return; }
        var r = pageRoute(u);
        if (!r) return;
        if (r.name === x.routeName) return;     // an anchor on the same page
        e.preventDefault();
        open(r.route);
      });
      // Clicking inside a frame is clicking the window.
      doc.addEventListener("mousedown", function () { closeMenus(); focus(x); });
      // A key pressed in a framed page never reaches this document, so the
      // desktop's shortcuts listen there too.
      doc.addEventListener("keydown", onKeyDown);
    });
    x.body.appendChild(f);
  }

  // A program's window: its gallery picture beside its Terminal Guide entry.
  // A terminal program's entry is set in a foot window, as it would be read.
  // A program's window is its details, and they go at a click anywhere: in
  // the window (not on a link, not while selecting text), on the desktop
  // around it, or on the page outside the panel; Esc too. From inside the
  // desktop the menu it came from comes back, for the next pick.
  function dismiss(x, again) {
    close(x);
    if (again && x.from === "gui") gui.open({ quiet: true });
    else if (again && x.from === "keys") keys.open();
  }
  function dismissDetails(again) {
    var here = onSpace(current).filter(function (y) { return y.detail; });
    if (here.length) dismiss(here[here.length - 1], again);
  }
  document.addEventListener("click", function (e) {
    if (root.contains(e.target) || root.classList.contains("full")) return;
    wins.filter(function (y) { return y.detail; }).forEach(function (y) { close(y); });
  });

  function program(x, item) {
    var cmd = item.cmd, u = shot(cmd), a = byCmd[cmd];
    x.detail = true;
    x.from = item.from || null;
    x.el.addEventListener("click", function (e) {
      if (e.target.closest("a, button")) return;
      if (String(window.getSelection() || "")) return;
      dismiss(x, true);
    });
    var hint = el("span", "tip", "click anywhere to close");
    x.el.querySelector(".desk-head").insertBefore(hint, x.el.querySelector(".desk-head .shut"));
    var term = item.kind === "term" || item.kind === "help" || !!(a && a.terminal);
    x.el.classList.add("app");
    if (term) x.el.classList.add("foot");

    // The title bar: the full entry, the man page, the project's home.
    var links = el("span", "links");
    x.el.querySelector(".desk-head").insertBefore(links, x.el.querySelector(".shut"));
    function link(text, href, off) {
      var l = el("a", null, text);
      l.href = href;
      if (off) { l.target = "_blank"; l.rel = "noopener"; }
      links.appendChild(l);
    }

    // The picture, where the gallery has one; without one the entry has the
    // window to itself rather than half of it beside an empty frame.
    var pic = null;
    if (u) {
      pic = el("div", "desk-pic");
      pic.style.backgroundImage = "url(" + u + ")";
      x.el.classList.add("pictured");
    }
    var txt = el("div", "desk-txt");
    // Examples and See also, under both: examples are wide, and in a column
    // beside a picture they would be cut off.
    var more = el("div", "desk-txt desk-more");
    txt.appendChild(el("h2", null, x.title));
    var lede = el("p", "lede", refs[cmd] || (a && (a.desc || a.generic)) || "");
    txt.appendChild(lede);
    var run = item.kind === "install" ? "doas copal-install " + cmd : cmd;
    txt.appendChild(el("p", "cmd", "$ " + run));
    if (pic) x.body.appendChild(pic);
    x.body.appendChild(txt);
    x.body.appendChild(more);

    withCards(function (cs) {
      var c = cs[cmd];
      // Opened by its address rather than from a menu, a terminal program is
      // known by the guide's record of it.
      if (c && (c.m === "t" || c.m === "h") && !term) {
        term = true;
        x.el.classList.add("foot");
      }
      if (c) {
        link("Guide", "#page/commands/c-" + cmd);
        if (c.man) link("man", "#man/" + cmd);
        lede.textContent = c.p;
        if (c.why) txt.appendChild(prose("p", c.why)).classList.add("why");
        (c.use || []).forEach(function (p) { txt.appendChild(prose("p", p)); });
        if (c.ex && c.ex.length) {
          more.appendChild(el("h3", null, "Examples"));
          var pre = el("pre", "ex");
          c.ex.forEach(function (line) {
            var m = line.match(/^(.*?)(\s+#\s.*)?$/), row = el("div");
            row.appendChild(el("span", "run", m[1]));
            if (m[2]) row.appendChild(el("span", "note", m[2]));
            pre.appendChild(row);
          });
          more.appendChild(pre);
        }
        if (c.see && c.see.length) {
          var see = el("p", "see", "See also: ");
          c.see.forEach(function (w, i) {
            if (i) see.appendChild(document.createTextNode(", "));
            var l = el("a"); l.href = "#app/" + w; l.appendChild(el("code", null, w));
            see.appendChild(l);
          });
          more.appendChild(see);
        }
        if (!c.why && !c.use) txt.appendChild(el("p", "thin", "The guide has this one's facts and its man page, but no written entry yet."));
      } else if (a && a.desc && a.desc !== lede.textContent) {
        txt.appendChild(el("p", null, a.desc));
      }
      if (homes[cmd]) link(homes[cmd].replace(/^https?:\/\/(www\.)?/, "").replace(/\/.*$/, "") + " ↗", homes[cmd], true);
    });
  }

  // ----- addresses -----
  function appRoute(cmd) { return "app/" + cmd; }
  function pageRoute(u) {
    var mm = u.pathname.match(/\/man\/([A-Za-z0-9][\w.+@-]*)\.html$/);
    if (mm) return { name: "man/" + mm[1], route: "man/" + mm[1] };
    var m = u.pathname.match(/\/([a-z0-9-]*)(?:\.html)?$/);
    var name = m && m[1] ? m[1] : "index";   // the site's root is its front page
    if (!PAGES[name]) return null;
    var anchor = u.hash ? u.hash.slice(1) : "";
    return { name: name, route: "page/" + name + (anchor ? "/" + anchor : "") };
  }
  function parse(route) {
    var m = route.match(/^page\/([a-z0-9-]+)(?:\/(.+))?$/);
    if (m && PAGES[m[1]]) return { kind: "page", name: m[1], file: m[1] + ".html" + (m[2] ? "#" + m[2] : ""), title: PAGES[m[1]] };
    m = route.match(/^man\/([A-Za-z0-9][\w.+@-]*)$/);
    if (m) return { kind: "page", name: "man/" + m[1], file: "man/" + m[1] + ".html", title: "man " + m[1] };
    m = route.match(/^app\/([A-Za-z0-9][\w.+@-]*)$/);
    if (m) return { kind: "app", cmd: m[1] };
    return null;
  }

  function open(route, item, restoring) {
    var r = parse(route);
    if (!r) return null;
    closeMenus();
    var same = wins.filter(function (y) { return y.route === route; })[0];
    if (same) {
      if (item && item.from) same.from = item.from;   // picked again, from this menu
      focus(same);
      return same;
    }
    // A page opened again at another anchor is the same window, moved there.
    if (r.kind === "page") {
      var pg = wins.filter(function (y) { return y.routeName === r.name; })[0];
      if (pg) {
        pg.route = route;
        pg.body.querySelector("iframe").src = r.file;
        focus(pg);
        if (!restoring) history.pushState(null, "", "#" + route);
        return pg;
      }
    }
    var a = r.kind === "app" ? byCmd[r.cmd] : null;
    var x = {
      route: route, routeName: r.kind === "page" ? r.name : null,
      title: r.kind === "page" ? r.title : (item && item.name) || (a && a.name) || r.cmd,
      ws: placeFor()
    };
    x.el = el("section", "desk-win");
    x.el.tabIndex = -1;
    x.el.setAttribute("aria-label", x.title);
    var head = el("header", "desk-head");
    x.name = el("span", "name", x.title);
    var shut = el("button", "shut", "×");
    shut.title = "Close (Ctrl+Alt+Q)";
    shut.setAttribute("aria-label", "Close " + x.title);
    shut.addEventListener("click", function (e) { e.stopPropagation(); close(x); });
    head.appendChild(x.name); head.appendChild(shut);
    x.body = el("div", "desk-body");
    x.el.appendChild(head); x.el.appendChild(x.body);
    x.el.addEventListener("mousedown", function () { focus(x); });
    x.el.addEventListener("click", function (e) { e.stopPropagation(); closeMenus(); });
    if (r.kind === "page") frame(x, r); else program(x, item || { cmd: r.cmd, kind: a && a.terminal ? "term" : "run" });
    // The welcome window gives up its smaller first-visit size as soon as
    // another window shares its workspace: from then on, it tiles.
    onSpace(x.ws).forEach(function (y) { y.el.classList.remove("intro"); });
    spaces[x.ws - 1].appendChild(x.el);
    wins.push(x);
    if (!restoring) history.pushState(null, "", "#" + route);
    focus(x);
    return x;
  }

  function close(x, quiet) {
    if (!x) return;
    x.el.remove();
    wins.splice(wins.indexOf(x), 1);
    if (quiet) return;
    var here = onSpace(current);
    var next = here.length ? here[here.length - 1] : (wins.length ? wins[wins.length - 1] : null);
    if (next) focus(next);
    else { focused = null; history.replaceState(null, "", location.pathname); paintBar(); }
  }

  // Back closes what the last step opened; Forward opens it again.
  window.addEventListener("popstate", function () {
    var route = location.hash.slice(1);
    var have = wins.filter(function (y) { return y.route === route; })[0];
    if (have) {
      // Everything opened after it goes, newest first.
      while (wins.length && wins[wins.length - 1] !== have) close(wins[wins.length - 1], true);
      focus(have, true);
    } else if (route) {
      open(route, null, true);
    } else {
      while (wins.length) close(wins[wins.length - 1], true);
      focused = null;
    }
    showWorkspace(focused ? focused.ws : current);
  });

  // ----- keys -----
  // Copal's own Ctrl+Alt shortcuts (hyprland.conf binds them for machines
  // where Super is taken): A copal-gui, Space copal-menu, Z its System pane,
  // Q close the window, 1-5 a workspace.
  //
  // NOT SUPER, on purpose. On a Copal machine Hyprland takes Super before the
  // browser sees it; everywhere else Super is Cmd or the Windows key, and the
  // browser and the system own its combinations -- Cmd+A selects, Cmd+1 picks
  // a tab, Cmd+Q quits. Taking them over broke those, and a lone Super tap
  // could not be told apart from a Cmd+Tab the page never saw the rest of:
  // the menu opened by itself.
  function shortcut(e) {
    if (!(e.ctrlKey && e.altKey && !e.metaKey)) return false;
    var c = e.code || "";
    if (c === "KeyA") { keys.close(); gui.toggle(); return true; }
    if (c === "Space") { gui.close(); keys.toggle("apps"); return true; }
    if (c === "KeyZ") { gui.close(); keys.toggle("system"); return true; }
    if (c === "KeyQ") { closeMenus(); if (focused) close(focused); return true; }
    var n = c.match(/^Digit([1-5])$/);
    if (n) { closeMenus(); showWorkspace(+n[1]); return true; }
    return false;
  }
  function onKeyDown(e) {
    if (shortcut(e)) { e.preventDefault(); return; }
    if (gui.isOpen()) { if (gui.key(e)) e.preventDefault(); return; }
    if (keys.isOpen()) { if (keys.key(e)) e.preventDefault(); return; }
    // Esc: a program's details go, as a click would take them.
    if (e.key === "Escape" && focused && focused.detail) { dismiss(focused, true); e.preventDefault(); }
  }
  document.addEventListener("keydown", onKeyDown);

  // For tools/desk-check: arrive as scrolling into view does, and the screen.
  window.CopalDesk = { arrive: arrive, full: setFull };

  // ----- first light -----
  showWorkspace(1);
  document.documentElement.classList.add("desk-on");
  var start0 = location.hash.slice(1);
  if (start0 && parse(start0)) {
    // A shared address: straight into the desktop, with that window.
    started = true;
    [bGui, bKeys].forEach(function (b) { b.classList.remove("pulse"); });
    setFull(true);
    open(start0, null, true);
  } else {
    setFull(false);
    if (window.IntersectionObserver) {
      var seen = new IntersectionObserver(function (es) {
        if (es[0].isIntersecting) { seen.disconnect(); arrive(); }
      }, { threshold: 0.5 });
      seen.observe(root);
    } else arrive();
  }
})();
