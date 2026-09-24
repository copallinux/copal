/* The live menu on the home page: copal-gui, simulated.
 *
 * It behaves the way tools/copal-gui does, rule for rule:
 *   - hovering a section switches to it after 120 ms, so sweeping the
 *     pointer across towards the programs does not flick through them;
 *   - hovering a program selects it and names it below the list, with its
 *     one-line description;
 *   - typing anywhere searches: words matched at the start of the name,
 *     command, keywords and description, then a plain substring on the name
 *     and command; the first match is selected, Enter starts it;
 *   - Up and Down move through the list; Esc clears the search, then closes;
 *   - right-click adds a program to the favourites column, or removes it;
 *   - a click outside the menu closes it; the bar's button opens it again.
 *
 * What the page adds is the picture: hovering a program shows the gallery's
 * shot of it running, and starting one puts that shot on the screen -- what
 * the click would have given you. The entries, icons and favourites are the
 * real menu's, from tools/copal-menu-sim.py; nothing here is typed by hand.
 */
(function () {
  "use strict";
  var D = window.COPAL_MENU;
  var host = document.getElementById("menu-sim");
  if (!D || !host) return;

  var W = 1280, H = 800;
  var FAVKEY = "copal-sim-favourites";
  var apps = D.apps, byId = {}, refs = D.refs || {};
  function manLink(cmd) {
    var a = el("a", null, "man " + cmd);
    a.href = "commands.html#c-" + encodeURIComponent(cmd);
    return a;
  }
  apps.forEach(function (a) { byId[a.id] = a; });

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function icon(i, size) {
    var s = el("span", "sim-ico");
    if (i < 0) return s;
    s.style.width = s.style.height = size + "px";
    s.style.backgroundImage = "url(img/menu/icons.png)";
    s.style.backgroundSize = (D.cols * size) + "px auto";
    s.style.backgroundPosition = (-(i % D.cols) * size) + "px " + (-Math.floor(i / D.cols) * size) + "px";
    return s;
  }
  function fold(s) { return (s || "").toLocaleLowerCase(); }

  // ----- favourites: the machine's starter set, then whatever you change -----
  var favs;
  try { favs = JSON.parse(localStorage.getItem(FAVKEY) || "null"); } catch (e) { favs = null; }
  if (!Array.isArray(favs)) favs = D.favourites.slice();
  favs = favs.filter(function (i) { return byId[i]; });
  function saveFavs() { try { localStorage.setItem(FAVKEY, JSON.stringify(favs)); } catch (e) { /* private window */ } }

  // ----- the stage -----
  var wrap = el("div", "sim-wrap");
  wrap.tabIndex = 0;
  wrap.setAttribute("role", "application");
  wrap.setAttribute("aria-label", "A working copy of the Copal menu on the Hyprland desktop");
  var st = el("div", "sim");
  st.style.backgroundImage = "url(img/menu/wallpaper.jpg)";
  wrap.appendChild(st);

  // The bar.
  var bar = el("div", "sim-bar");
  var burger = el("button", null, "≡");
  burger.title = "The menu (Super)";
  var ws = el("div", "sim-ws");
  [1, 2, 3, 4, 5].forEach(function (n) {
    var s = el("span", n === 5 ? "on" : "", String(n));
    s.addEventListener("click", function () {
      Array.prototype.forEach.call(ws.children, function (c) { c.className = ""; });
      s.className = "on";
    });
    ws.appendChild(s);
  });
  var title = el("span", "grow", "");
  var stat = el("span", null, "c12%  m19%  d48%   eth up");
  var tbar = el("span", "time", "");
  bar.appendChild(burger); bar.appendChild(ws); bar.appendChild(title); bar.appendChild(stat); bar.appendChild(tbar);
  st.appendChild(bar);

  // The desktop's clock.
  var clock = el("div", "sim-clock");
  var hm = el("div", "hm"), dt = el("div", "date");
  clock.appendChild(hm); clock.appendChild(dt);
  st.appendChild(clock);
  function tick() {
    var d = new Date();
    var t = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
    hm.textContent = t; tbar.textContent = t;
    dt.textContent = d.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
  }
  tick(); setInterval(tick, 10000);

  // The menu.
  var menu = el("div", "sim-menu");
  var side = el("div", "sim-side");
  var favCol = el("div", "col"), sessCol = el("div", "col sess");
  side.appendChild(favCol); side.appendChild(sessCol);
  var main = el("div", "sim-main");
  var search = el("div", "sim-search");
  search.innerHTML = '<svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true"><circle cx="6.5" cy="6.5" r="4.8" fill="none" stroke="#333" stroke-width="1.7"/><path d="M10 10l4.2 4.2" stroke="#333" stroke-width="1.9" stroke-linecap="round"/></svg>';
  var q = el("span", "q"), caret = el("span", "caret");
  search.appendChild(q); search.appendChild(caret);
  var body = el("div", "sim-body");
  var secs = el("div", "sim-secs"), list = el("div", "sim-apps");
  body.appendChild(secs); body.appendChild(list);
  var foot = el("div", "sim-foot");
  var fname = el("div", "n"), fdesc = el("div", "d");
  foot.appendChild(fname); foot.appendChild(fdesc);
  main.appendChild(search); main.appendChild(body); main.appendChild(foot);
  menu.appendChild(side); menu.appendChild(main);
  st.appendChild(menu);

  // Hover's picture, and the running program's screen.
  var peek = el("div", "sim-peek");
  var pshot = el("div", "shot"), pcap = el("div", "cap");
  peek.appendChild(pshot); peek.appendChild(pcap);
  st.appendChild(peek);
  var run = el("div", "sim-run");
  var pill = el("div", "pill"), pillT = el("span"), pillX = el("button", null, "Close  ×");
  pill.appendChild(pillT); pill.appendChild(pillX);
  var runNone = el("div", "none");
  run.appendChild(runNone); run.appendChild(pill);
  st.appendChild(run);
  var veil = el("div", "sim-veil");
  st.appendChild(veil);
  var ctx = el("div", "sim-ctx");
  st.appendChild(ctx);

  // ----- state -----
  var state = { section: "All Applications", query: "", rank: null, sel: null, open: true, running: null };
  var rows = {};

  function describe(a, text) {
    if (a) { fname.textContent = a.name; fdesc.textContent = a.desc || a.generic || ""; }
    else { fname.textContent = text || ""; fdesc.textContent = ""; }
  }
  function shotUrl(a, big) {
    if (big && a.big) return "img/site/" + a.big + ".jpg";
    return a.shot ? "img/gallery/" + a.shot + ".jpg" : null;
  }
  function showPeek(a) {
    if (!a) { peek.classList.remove("on"); return; }
    var u = shotUrl(a, true);
    pshot.className = "shot" + (u ? "" : " none");
    pshot.style.backgroundImage = u ? "url(" + u + ")" : "";
    pshot.textContent = "";
    var man = !u && refs[a.exec];
    if (!u) {
      var b = icon(a.icon, 32); b.style.transform = "scale(2.5)";
      pshot.appendChild(b);
    }
    pcap.innerHTML = "";
    var b2 = el("b", null, a.name);
    pcap.appendChild(b2);
    if (man) {
      pcap.appendChild(document.createTextNode(" — " + (a.terminal ? "terminal command" : "command") + ": " + refs[a.exec] + " See "));
      pcap.appendChild(manLink(a.exec));
      pcap.appendChild(document.createTextNode("."));
    } else {
      pcap.appendChild(document.createTextNode(u
        ? " — what it opens to, from the gallery. Click to start it."
        : " — no picture in the gallery yet. Click to start it."));
    }
    peek.classList.add("on");
  }

  // ----- sections -----
  var secRows = [];
  D.sections.forEach(function (s) {
    var r = el("div", "sim-sec");
    r.appendChild(icon(s.icon, 24));
    r.appendChild(el("span", null, s.name));
    r._name = s.name;
    var timer = 0;
    r.addEventListener("mouseenter", function () {
      clearTimeout(timer);
      if (state.section === s.name && state.rank === null) return;
      timer = setTimeout(function () { selectSection(s.name); }, 120);
    });
    r.addEventListener("mouseleave", function () { clearTimeout(timer); });
    r.addEventListener("click", function () { selectSection(s.name); });
    secs.appendChild(r); secRows.push(r);
  });
  function paintSections() {
    secRows.forEach(function (r) { r.classList.toggle("on", r._name === state.section); });
  }
  function selectSection(name) {
    if (state.section === name && state.rank === null) return;
    state.section = name;
    if (state.query) setQuery(""); else refilter();
    paintSections();
    list.scrollTop = 0;
  }

  // ----- the programs -----
  apps.forEach(function (a) {
    var r = el("div", "sim-app");
    r.appendChild(icon(a.icon, 24));
    r.appendChild(el("span", "n", a.name));
    if (a.terminal) r.appendChild(el("span", "t", "terminal"));
    r._app = a;
    r.addEventListener("mousemove", function () { if (state.sel !== a) select(a, false); });
    r.addEventListener("click", function () { launch(a); });
    r.addEventListener("contextmenu", function (e) { e.preventDefault(); favMenu(a, e); });
    list.appendChild(r); rows[a.id] = r;
  });
  list.addEventListener("mouseleave", function () { showPeek(null); });

  function visible(a) {
    if (state.rank) return a.id in state.rank;
    var s = state.section;
    return s === "All Applications" || (s === "Favourites" && favs.indexOf(a.id) >= 0) || a.section === s;
  }
  function ordered() {
    var v = apps.filter(visible);
    if (state.rank) {
      v.sort(function (x, y) {
        return (state.rank[x.id] - state.rank[y.id]) || (fold(x.name) < fold(y.name) ? -1 : 1);
      });
    }
    return v;
  }
  function refilter() {
    var v = ordered();
    // Reorder the nodes to the list's order; hide the rest.
    apps.forEach(function (a) { rows[a.id].style.display = "none"; });
    v.forEach(function (a) { rows[a.id].style.display = ""; list.appendChild(rows[a.id]); });
    if (state.sel && !visible(state.sel)) { paintSel(null); describe(); }
    return v;
  }
  function paintSel(a) {
    if (state.sel) rows[state.sel.id].classList.remove("on");
    state.sel = a;
    if (a) rows[a.id].classList.add("on");
  }
  function select(a, scroll) {
    paintSel(a);
    describe(a);
    showPeek(a);
    if (scroll && a) {
      var r = rows[a.id], top = r.offsetTop - list.offsetTop;
      if (top < list.scrollTop) list.scrollTop = top;
      else if (top + r.offsetHeight > list.scrollTop + list.clientHeight)
        list.scrollTop = top + r.offsetHeight - list.clientHeight;
    }
  }

  // ----- search: GIO's word-prefix match first, then copal-gui's substring -----
  function setQuery(t) {
    state.query = t;
    q.textContent = t;
    var s = t.trim();
    if (!s) state.rank = null;
    else {
      var words = fold(s).split(/\s+/), rank = {};
      apps.forEach(function (a) {
        var fields = [a.name, a.exec, a.keywords + " " + a.generic, a.desc, a.id.replace(/\.desktop$/, "")];
        var best = null;
        for (var f = 0; f < fields.length && best === null; f++) {
          var toks = fold(fields[f]).split(/[^\p{L}\p{N}+#]+/u);
          var all = words.every(function (w) { return toks.some(function (k) { return k.indexOf(w) === 0; }); });
          if (all) best = (f === 0 && fold(a.name).indexOf(words[0]) === 0) ? 0 : f + 1;
        }
        if (best === null) {
          var low = fold(s);
          if (fold(a.name).indexOf(low) >= 0 || fold(a.exec).indexOf(low) >= 0) best = 9;
        }
        if (best !== null) rank[a.id] = best;
      });
      state.rank = rank;
    }
    var v = refilter();
    list.scrollTop = 0;
    if (v.length) select(v[0], false);
    else { paintSel(null); showPeek(null); describe(null, s ? "Nothing matches '" + s + "'" : ""); }
    if (!s) { paintSel(null); showPeek(null); describe(); }
  }

  // ----- favourites and the session -----
  function paintFavs() {
    favCol.innerHTML = "";
    favs.forEach(function (i) {
      var a = byId[i], b = el("div", "sim-ib");
      b.title = a.name;
      b.appendChild(icon(a.icon, 32));
      b.addEventListener("mouseenter", function () { describe(a); showPeek(a); });
      b.addEventListener("mouseleave", function () { showPeek(null); });
      b.addEventListener("click", function () { launch(a); });
      b.addEventListener("contextmenu", function (e) { e.preventDefault(); favMenu(a, e); });
      favCol.appendChild(b);
    });
  }
  var SESSION = {
    "Lock screen": function (t) { return '<div class="big">' + t + '</div><div>Locked. Click to unlock.</div>'; },
    "Log out": function () { return "<div>Hyprland would exit here, back to the login prompt.</div><div>Click to log in again.</div>"; },
    "Restart": function () { return "<div>copal-halt would ask first, then restart the machine.</div><div>Click to come back.</div>"; },
    "Shut down": function () { return "<div>copal-halt would ask first, then power off.</div><div>Click to come back.</div>"; }
  };
  D.session.forEach(function (s) {
    var b = el("div", "sim-ib");
    b.title = s.name;
    b.appendChild(icon(s.icon, 24));
    b.addEventListener("mouseenter", function () { describe(null, s.name); showPeek(null); });
    b.addEventListener("click", function () {
      closeMenu();
      veil.innerHTML = SESSION[s.name](hm.textContent);
      veil.classList.add("on");
    });
    sessCol.appendChild(b);
  });
  veil.addEventListener("click", function (e) { e.stopPropagation(); veil.classList.remove("on"); openMenu(); });

  function favMenu(a, e) {
    var on = favs.indexOf(a.id) >= 0;
    ctx.innerHTML = "";
    var item = el("div", null, on ? "Remove from favourites" : "Add to favourites");
    item.addEventListener("click", function (ev) {
      ev.stopPropagation();
      if (on) favs.splice(favs.indexOf(a.id), 1); else favs.push(a.id);
      saveFavs(); paintFavs(); refilter();
      ctx.classList.remove("on");
    });
    ctx.appendChild(item);
    var p = toStage(e);
    ctx.style.left = Math.min(p.x, W - 200) + "px";
    ctx.style.top = Math.min(p.y, H - 40) + "px";
    ctx.classList.add("on");
  }

  // ----- starting a program: its screen, from the gallery -----
  function launch(a) {
    closeMenu();
    state.running = a;
    var u = shotUrl(a, true);
    run.style.backgroundImage = u ? "url(" + u + ")" : "";
    runNone.innerHTML = "";
    if (!u) {
      var b = icon(a.icon, 32); b.style.transform = "scale(3)"; b.style.margin = "0 auto 24px";
      runNone.appendChild(b);
      runNone.appendChild(el("div", null, a.name + " would be running here."));
      runNone.appendChild(el("div", null, a.terminal ? "A terminal command, in foot." : "The gallery has no picture of it yet."));
      if (refs[a.exec]) {
        var ml = manLink(a.exec); ml.className = "tm-manlink"; ml.textContent = "see man " + a.exec + " →";
        runNone.appendChild(ml);
      }
    }
    pillT.textContent = a.name + (a.terminal ? " — in foot" : "") + (u ? " — the gallery's picture of it running" : "");
    title.textContent = a.name;
    run.classList.add("on");
  }
  function stopRunning() {
    run.classList.remove("on");
    state.running = null;
    title.textContent = "";
    openMenu();
  }
  pillX.addEventListener("click", function (e) { e.stopPropagation(); stopRunning(); });
  run.addEventListener("click", function (e) { e.stopPropagation(); });

  // ----- open, close -----
  function openMenu() {
    state.open = true; menu.hidden = false;
    setQuery("");
    list.scrollTop = 0;
  }
  function closeMenu() {
    state.open = false; menu.hidden = true;
    showPeek(null); ctx.classList.remove("on");
  }
  burger.addEventListener("click", function (e) {
    e.stopPropagation();
    if (state.running) { stopRunning(); return; }
    if (state.open) closeMenu(); else openMenu();
  });
  menu.addEventListener("click", function (e) { e.stopPropagation(); ctx.classList.remove("on"); });
  menu.addEventListener("mouseleave", function () { showPeek(null); });
  st.addEventListener("click", function () {
    // The layer-shell backdrop: a click that misses the menu closes it.
    ctx.classList.remove("on");
    if (state.open) closeMenu();
  });
  st.addEventListener("contextmenu", function (e) { if (!e.defaultPrevented) e.preventDefault(); });

  // ----- keys, while the picture has focus -----
  wrap.addEventListener("focus", function () { search.classList.add("focus"); });
  wrap.addEventListener("blur", function () { search.classList.remove("focus"); });
  wrap.addEventListener("keydown", function (e) {
    if (veil.classList.contains("on")) { veil.classList.remove("on"); openMenu(); e.preventDefault(); return; }
    if (e.key === "Meta" || e.key === "OS") {
      if (state.running) stopRunning(); else if (state.open) closeMenu(); else openMenu();
      e.preventDefault(); return;
    }
    if (state.running) {
      if (e.key === "Escape") { stopRunning(); e.preventDefault(); }
      return;
    }
    if (!state.open) {
      if (e.key === "Enter" || e.key === " ") { openMenu(); e.preventDefault(); }
      return;
    }
    var v = ordered(), i = state.sel ? v.indexOf(state.sel) : -1;
    if (e.key === "Escape") {
      if (state.query) setQuery(""); else closeMenu();
    } else if (e.key === "ArrowDown") {
      if (v.length) select(v[Math.min(i + 1, v.length - 1)], true);
    } else if (e.key === "ArrowUp") {
      if (v.length) select(v[Math.max(i - 1, 0)], true);
    } else if (e.key === "Enter") {
      if (state.sel && visible(state.sel)) launch(state.sel);
    } else if (e.key === "Backspace") {
      setQuery(state.query.slice(0, -1));
    } else if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
      setQuery(state.query + e.key);
    } else {
      return;
    }
    e.preventDefault();
  });
  wrap.addEventListener("mousedown", function () { if (document.activeElement !== wrap) wrap.focus({ preventScroll: true }); });

  // ----- scale the 1280x800 desktop to the plate -----
  var scale = 1;
  function fit() {
    scale = wrap.clientWidth / W;
    st.style.transform = "scale(" + scale + ")";
  }
  function toStage(e) {
    var r = st.getBoundingClientRect();
    return { x: (e.clientX - r.left) / scale, y: (e.clientY - r.top) / scale };
  }
  if (window.ResizeObserver) new ResizeObserver(fit).observe(wrap);
  window.addEventListener("resize", fit);

  // ----- in place of the screenshot -----
  var img = host.querySelector("img");
  host.insertBefore(wrap, host.firstChild);
  if (img) img.style.display = "none";
  var hint = host.querySelector(".sim-hint");
  if (hint) hint.hidden = false;
  paintFavs(); paintSections(); refilter(); describe(); fit();
})();
