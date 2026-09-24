/* The desktop that is the site (docs/splash-plan.md).
 *
 * index.html is Copal's Hyprland desktop, full screen: the bar, the clock,
 * the wallpaper, and the two menus -- copal-gui (Super+A, menu-gui.js) and
 * copal-menu (Super+Space and Super+Z, menu-keys.js). Everything on the site
 * opens from them as a window:
 *
 *   #page/NAME   a page of the site, framed: about, install, commands ...
 *   #app/CMD     a program: its gallery picture and where it is documented
 *
 * Windows tile the way Hyprland tiles them. One fills the workspace, two
 * split it, and a third goes to the next workspace with room, which the bar's
 * 1-5 then show; on a narrow screen a workspace holds one. Every window has an
 * address, so it can be shared, and opening one is a step in the browser's
 * history: Back closes it again.
 *
 * Without JavaScript none of this runs, and index.html's own list of pages is
 * the page.
 */
(function () {
  "use strict";
  var D = window.COPAL_MENU;
  var root = document.getElementById("desk");
  if (!D || !root || !window.CopalMenus) return;

  var WORKSPACES = 5;
  // The pages a window may frame: the site's own, by file stem. Nothing else
  // is framed, so an address cannot put another site inside this one.
  var PAGES = {
    about: "About Copal", desktop: "The Desktop", install: "The Installer",
    platforms: "Platforms", alpine: "Alpine Linux", software: "Software",
    gallery: "Gallery", commands: "The Terminal Guide",
    "terminal-guide-lab-report": "Writing a Command Reference Against the Machine"
  };

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

  // ----- the desktop -----
  root.className = "desk";
  root.style.backgroundImage = "url(img/menu/wallpaper.jpg)";
  root.setAttribute("role", "application");
  root.setAttribute("aria-label", "The Copal desktop. Its menus open every page of the site as a window.");

  var bar = el("div", "sim-bar");
  var bGui = el("button", "desk-menu", "≡");
  bGui.title = "Applications — copal-gui (Super+A)";
  bGui.setAttribute("aria-label", bGui.title);
  var bKeys = el("button", "desk-menu keys", "❯_");
  bKeys.title = "copal-menu (Super+Space; Super+Z for its System pane)";
  bKeys.setAttribute("aria-label", bKeys.title);
  var wsBox = el("div", "sim-ws");
  var wsTabs = [];
  for (var n = 1; n <= WORKSPACES; n++) {
    (function (n) {
      var s = el("span", "", String(n));
      s.setAttribute("role", "button");
      s.title = "Workspace " + n;
      s.addEventListener("click", function (e) { e.stopPropagation(); showWorkspace(n); });
      wsBox.appendChild(s); wsTabs.push(s);
    })(n);
  }
  var title = el("span", "grow", "");
  var stat = el("span", "stat", "c12%  m19%  d48%   eth up");
  var tbar = el("span", "time", "");
  [bGui, bKeys, wsBox, title, stat, tbar].forEach(function (x) { bar.appendChild(x); });
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
  var desk = { launch: function (item) { open(appRoute(item.cmd), item); }, clock: function () { return hm.textContent; }, shot: shot };
  var gui = window.CopalMenus.gui(D, root, desk);
  var keys = window.CopalMenus.keys(D, root, desk);
  function closeMenus() { gui.close(); keys.close(); }
  bGui.addEventListener("click", function (e) { e.stopPropagation(); keys.close(); gui.toggle(); });
  bKeys.addEventListener("click", function (e) { e.stopPropagation(); gui.close(); keys.toggle(); });
  // The layer-shell backdrop: a click that misses a menu closes it.
  root.addEventListener("click", closeMenus);
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
      t.className = (i + 1 === current ? "on" : "") + (onSpace(i + 1).length ? " used" : "");
    });
    title.textContent = focused ? focused.title : "";
  }
  function focus(x, quiet) {
    wins.forEach(function (y) { y.el.classList.toggle("focus", y === x); });
    focused = x;
    if (x && x.ws !== current) { showWorkspace(x.ws); return; }
    if (x && !quiet && location.hash !== "#" + x.route) history.replaceState(null, "", "#" + x.route);
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
    });
    x.body.appendChild(f);
  }

  function program(x, item) {
    var cmd = item.cmd, u = shot(cmd), a = byCmd[cmd];
    x.el.classList.add("app");
    var pic = el("div", "desk-pic" + (u ? "" : " none"));
    if (u) pic.style.backgroundImage = "url(" + u + ")";
    else pic.textContent = item.kind === "run" ? "No picture in the gallery yet." : "A terminal program, in foot.";
    var txt = el("div", "desk-txt");
    txt.appendChild(el("h2", null, x.title));
    var line = refs[cmd] || (a && (a.desc || a.generic)) || "";
    if (line) txt.appendChild(el("p", null, line));
    if (item.kind === "install") txt.appendChild(el("p", "cmd", "$ doas copal-install " + cmd));
    else txt.appendChild(el("p", "cmd", "$ " + cmd));
    if (refs[cmd]) {
      var g = el("a", "doc", "Terminal Guide: " + cmd + " →");
      g.href = "#page/commands/c-" + cmd;
      txt.appendChild(g);
    }
    if (homes[cmd]) {
      var h = el("a", "doc", homes[cmd].replace(/^https?:\/\/(www\.)?/, "").replace(/\/.*$/, "") + " ↗");
      h.href = homes[cmd]; h.target = "_blank"; h.rel = "noopener";
      txt.appendChild(h);
    }
    x.body.appendChild(pic); x.body.appendChild(txt);
  }

  // ----- addresses -----
  function appRoute(cmd) { return "app/" + cmd; }
  function pageRoute(u) {
    var m = u.pathname.match(/\/([a-z0-9-]*)(?:\.html)?$/);
    var name = m && m[1] ? m[1] : "about";   // the site's root is the desktop; its text is About
    if (!PAGES[name]) return null;
    var anchor = u.hash ? u.hash.slice(1) : "";
    return { name: name, route: "page/" + name + (anchor ? "/" + anchor : "") };
  }
  function parse(route) {
    var m = route.match(/^page\/([a-z0-9-]+)(?:\/(.+))?$/);
    if (m && PAGES[m[1]]) return { kind: "page", name: m[1], file: m[1] + ".html" + (m[2] ? "#" + m[2] : ""), title: PAGES[m[1]] };
    m = route.match(/^app\/([A-Za-z0-9][\w.+@-]*)$/);
    if (m) return { kind: "app", cmd: m[1] };
    return null;
  }

  function open(route, item, restoring) {
    var r = parse(route);
    if (!r) return null;
    closeMenus();
    var same = wins.filter(function (y) { return y.route === route; })[0];
    if (same) { focus(same); return same; }
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
    x.el.setAttribute("aria-label", x.title);
    var head = el("header", "desk-head");
    x.name = el("span", "name", x.title);
    var shut = el("button", "shut", "×");
    shut.title = "Close (Super+Q)";
    shut.setAttribute("aria-label", "Close " + x.title);
    shut.addEventListener("click", function (e) { e.stopPropagation(); close(x); });
    head.appendChild(x.name); head.appendChild(shut);
    x.body = el("div", "desk-body");
    x.el.appendChild(head); x.el.appendChild(x.body);
    x.el.addEventListener("mousedown", function () { focus(x); });
    x.el.addEventListener("click", function (e) { e.stopPropagation(); closeMenus(); });
    if (r.kind === "page") frame(x, r); else program(x, item || { cmd: r.cmd, kind: a && a.terminal ? "term" : "run" });
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
  document.addEventListener("keydown", function (e) {
    if (gui.isOpen()) { if (gui.key(e)) e.preventDefault(); return; }
    if (keys.isOpen()) { if (keys.key(e)) e.preventDefault(); return; }
    if (e.key === "Meta" || e.key === "OS") { gui.toggle(); e.preventDefault(); }
  });

  // ----- first light -----
  showWorkspace(1);
  var start = location.hash.slice(1);
  if (!start || !open(start, null, true)) {
    // No address, or one that names nothing: the welcome window, so nobody
    // lands on an empty desktop and has to guess.
    open("page/about", null, true);
    history.replaceState(null, "", "#page/about");
  }
  document.documentElement.classList.add("desk-on");
})();
