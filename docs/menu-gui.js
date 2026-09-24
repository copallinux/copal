/* copal-gui, the mouse's menu (Super+A), as a part of the site's desktop.
 *
 * It behaves the way tools/copal-gui does, rule for rule:
 *   - hovering a section switches to it after 120 ms, so sweeping the
 *     pointer across towards the programs does not flick through them;
 *   - hovering a program selects it and names it below the list, with its
 *     one-line description;
 *   - typing searches: words matched at the start of the name, command,
 *     keywords and description, then a plain substring on the name and
 *     command; the first match is selected, Enter starts it;
 *   - Up and Down move through the list; Esc clears the search, then closes;
 *   - right-click adds a program to the favourites column, or removes it;
 *   - the list scrolls by its edges: a strip one row high at the top and the
 *     bottom moves it at one steady pace while the pointer rests there.
 *
 * What the site adds is the picture: hovering a program shows the gallery's
 * shot of it running. Starting one is the desktop's business (desk.js): it
 * opens the program's window. The entries, icons and favourites are the real
 * menu's, from tools/copal-menu-sim.py; nothing here is typed by hand.
 */
(function () {
  "use strict";
  window.CopalMenus = window.CopalMenus || {};

  // layer: the desktop element to draw into. desk: { launch(app), clock() }.
  window.CopalMenus.gui = function (D, layer, desk) {
    var FAVKEY = "copal-sim-favourites";
    // The site's own pages are the Copal section: rows like any program's,
    // found by search, and kept out of All Applications, which is programs.
    var pages = (D.pages || []).map(function (p) {
      return { id: "page:" + p.page, name: p.title, section: "Copal", desc: p.desc, generic: "",
               keywords: "copal site page", exec: "", icon: p.icon, page: p.page };
    });
    var apps = D.apps.concat(pages), byId = {}, refs = D.refs || {};
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

    // ----- the menu -----
    var menu = el("div", "sim-menu");
    menu.hidden = true;
    menu.setAttribute("role", "dialog");
    menu.setAttribute("aria-label", "Applications (copal-gui, Super+A)");
    var side = el("div", "sim-side");
    var favCol = el("div", "col"), sessCol = el("div", "col sess");
    side.appendChild(favCol); side.appendChild(sessCol);
    var main = el("div", "sim-main");
    var search = el("div", "sim-search");
    search.innerHTML = '<svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true"><circle cx="6.5" cy="6.5" r="4.8" fill="none" stroke="#333" stroke-width="1.7"/><path d="M10 10l4.2 4.2" stroke="#333" stroke-width="1.9" stroke-linecap="round"/></svg>';
    // A real field, so a phone raises its keyboard and a screen reader hears
    // a search box; copal-gui's own is a GtkSearchEntry too.
    var q = el("input", "q");
    q.type = "search"; q.placeholder = "Type to search"; q.autocomplete = "off"; q.spellcheck = false;
    q.setAttribute("aria-label", "Search programs and pages");
    q.setAttribute("aria-controls", "gui-list");
    q.addEventListener("input", function () { setQuery(q.value); });
    search.appendChild(q);
    var body = el("div", "sim-body");
    var secs = el("div", "sim-secs"), list = el("div", "sim-apps");
    list.id = "gui-list";
    list.setAttribute("role", "listbox");
    list.setAttribute("aria-label", "Programs");
    secs.setAttribute("role", "tablist");
    secs.setAttribute("aria-label", "Sections");
    body.appendChild(secs); body.appendChild(list);
    var foot = el("div", "sim-foot");
    var fname = el("div", "n"), fdesc = el("div", "d");
    // What is selected, said aloud as it changes.
    foot.setAttribute("aria-live", "polite");
    foot.appendChild(fname); foot.appendChild(fdesc);
    main.appendChild(search); main.appendChild(body); main.appendChild(foot);
    menu.appendChild(side); menu.appendChild(main);
    layer.appendChild(menu);

    // Hover's picture; the session's screens; right-click.
    var peek = el("div", "sim-peek");
    var pshot = el("div", "shot"), pcap = el("div", "cap");
    peek.appendChild(pshot); peek.appendChild(pcap);
    layer.appendChild(peek);
    var veil = el("div", "sim-veil");
    layer.appendChild(veil);
    var ctx = el("div", "sim-ctx");
    layer.appendChild(ctx);

    // ----- state -----
    var state = { section: "All Applications", query: "", rank: null, sel: null, open: false };
    var rows = {};

    function describe(a, text) {
      if (a) { fname.textContent = a.name; fdesc.textContent = a.desc || a.generic || ""; }
      else { fname.textContent = text || ""; fdesc.textContent = ""; }
    }
    function shotUrl(a) {
      if (a.big) return "img/site/" + a.big + ".jpg";
      return a.shot ? "img/gallery/" + a.shot + ".jpg" : null;
    }
    function showPeek(a) {
      if (!a) { peek.classList.remove("on"); return; }
      var u = shotUrl(a), cmd = a.prog || a.exec;
      pshot.className = "shot" + (u ? "" : " none");
      pshot.style.backgroundImage = u ? "url(" + u + ")" : "";
      pshot.textContent = "";
      if (!u) {
        var b = icon(a.icon, 32); b.style.transform = "scale(2.5)";
        pshot.appendChild(b);
      }
      pcap.innerHTML = "";
      pcap.appendChild(el("b", null, a.name));
      if (a.page) { pcap.appendChild(document.createTextNode(" — " + a.desc + ". A page of this site: click to open it.")); peek.classList.add("on"); return; }
      pcap.appendChild(document.createTextNode(
        !u && refs[cmd] ? " — " + refs[cmd] + " Click to open it."
          : u ? " — what it opens to, from the gallery. Click to open it."
            : " — no picture in the gallery yet. Click to open it."));
      peek.classList.add("on");
    }

    // ----- sections -----
    var secRows = [];
    D.sections.forEach(function (s) {
      var r = el("div", "sim-sec");
      r.setAttribute("role", "tab");
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
      secRows.forEach(function (r) {
        r.classList.toggle("on", r._name === state.section);
        r.setAttribute("aria-selected", r._name === state.section ? "true" : "false");
      });
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
      r.id = "gui-" + a.id.replace(/[^\w-]/g, "_");
      r.setAttribute("role", "option");
      r.setAttribute("aria-selected", "false");
      r.appendChild(icon(a.icon, 24));
      r.appendChild(el("span", "n", a.name));
      if (a.terminal) r.appendChild(el("span", "t", "terminal"));
      else if (a.page) r.appendChild(el("span", "t", "page"));
      r._app = a;
      r.addEventListener("mousemove", function () { if (state.sel !== a) select(a, false); });
      r.addEventListener("click", function () { launch(a); });
      r.addEventListener("contextmenu", function (e) { e.preventDefault(); favMenu(a, e); });
      list.appendChild(r); rows[a.id] = r;
    });
    list.addEventListener("mouseleave", function () { showPeek(null); edgeStop(); });

    // Scrolling by the edges, as copal-gui does: hover selects and never moves
    // the list; a strip one row high at the top and at the bottom scrolls it
    // at one steady speed while the pointer rests there. The rows between stay
    // put, so a click lands on what was aimed at. The wheel scrolls as always.
    var EDGE = 24, STEP = 3, edge = { dir: 0, t: 0, x: 0, y: 0 };
    function edgeStop() { if (edge.t) clearInterval(edge.t); edge.t = 0; edge.dir = 0; }
    function edgeTick() {
      var before = list.scrollTop;
      list.scrollTop = before + edge.dir * STEP;
      if (list.scrollTop === before) { edgeStop(); return; }   // at the end
      var r = document.elementFromPoint(edge.x, edge.y);
      r = r && r.closest ? r.closest(".sim-app") : null;
      if (r && r._app && state.sel !== r._app) select(r._app, false);
    }
    list.addEventListener("mousemove", function (e) {
      var box = list.getBoundingClientRect(), y = e.clientY - box.top;
      var d = y < EDGE ? -1 : (y > list.clientHeight - EDGE ? 1 : 0);
      edge.x = e.clientX; edge.y = e.clientY;
      if (d !== edge.dir) { edgeStop(); edge.dir = d; if (d) edge.t = setInterval(edgeTick, 16); }
    });

    function visible(a) {
      if (state.rank) return a.id in state.rank;
      var s = state.section;
      return (s === "All Applications" && !a.page) || (s === "Favourites" && favs.indexOf(a.id) >= 0) || a.section === s;
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
      if (state.sel) { rows[state.sel.id].classList.remove("on"); rows[state.sel.id].setAttribute("aria-selected", "false"); }
      state.sel = a;
      if (a) { rows[a.id].classList.add("on"); rows[a.id].setAttribute("aria-selected", "true"); q.setAttribute("aria-activedescendant", rows[a.id].id); }
      else q.removeAttribute("aria-activedescendant");
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
      if (q.value !== t) q.value = t;
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
        close();
        veil.innerHTML = SESSION[s.name](desk.clock());
        veil.classList.add("on");
      });
      sessCol.appendChild(b);
    });
    veil.addEventListener("click", function (e) { e.stopPropagation(); veil.classList.remove("on"); open(); });

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
      var r = layer.getBoundingClientRect();
      ctx.style.left = Math.min(e.clientX - r.left, layer.clientWidth - 200) + "px";
      ctx.style.top = Math.min(e.clientY - r.top, layer.clientHeight - 40) + "px";
      ctx.classList.add("on");
    }

    // Both menus hand the desktop the same thing: what to open, by command.
    function launch(a) {
      close();
      if (a.page) { desk.launch({ page: a.page }); return; }
      desk.launch({ name: a.name, cmd: a.prog || a.exec, kind: a.terminal ? "term" : "run" });
    }

    // ----- open, close -----
    function open() {
      state.open = true; menu.hidden = false;
      setQuery("");
      list.scrollTop = 0;
      search.classList.add("focus");
      q.focus({ preventScroll: true });
    }
    function close() {
      state.open = false; menu.hidden = true;
      showPeek(null); ctx.classList.remove("on"); search.classList.remove("focus"); edgeStop();
      if (document.activeElement === q) q.blur();
    }
    menu.addEventListener("click", function (e) { e.stopPropagation(); ctx.classList.remove("on"); });
    menu.addEventListener("mouseleave", function () { showPeek(null); });

    // ----- keys, while the menu is open -----
    // Typing and Backspace belong to the field when it has the focus; the
    // rest -- arrows, Enter, Esc -- are the menu's wherever the focus is.
    function key(e) {
      if (veil.classList.contains("on")) { veil.classList.remove("on"); open(); return true; }
      if (!state.open) return false;
      if (e.target === q && (e.key.length === 1 || e.key === "Backspace")) return false;
      var v = ordered(), i = state.sel ? v.indexOf(state.sel) : -1;
      if (e.key === "Escape") {
        if (state.query) setQuery(""); else close();
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
        return false;
      }
      return true;
    }

    paintFavs(); paintSections(); refilter(); describe();
    return {
      open: open, close: close, key: key,
      isOpen: function () { return state.open; },
      toggle: function () { if (state.open) close(); else open(); }
    };
  };
})();
