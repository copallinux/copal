/* copal-menu, the keyboard's menu (Super+Space, Super+Z), as a part of the
 * site's desktop.
 *
 * It walks copal-menu's own list (the jgmenu-dialect CSV the real one caches
 * in ~/.cache/copal), the way walk() does on Wayland with wofi:
 *   - two panes: [ Applications ], every program flat, and [ System ], the
 *     categories, settings, Install and the session; Left and Right cross
 *     between them, and inside a category Left is Back;
 *   - typing filters the rows, case-insensitively, as wofi --insensitive;
 *   - Enter or a click runs a row, enters a section, or goes back;
 *   - Esc closes it.
 * Hover or the arrows select a row, and the card beside the menu says what it
 * opens to: the gallery's picture of it, or -- for a terminal command with no
 * picture -- its line in the Terminal Guide. Running a row is the desktop's
 * business (desk.js): it opens the program's window.
 */
(function () {
  "use strict";
  window.CopalMenus = window.CopalMenus || {};

  var RULE = "──";

  // What a row runs: install, a command's --help, a terminal program, or a
  // program. Shared with desk.js, which opens the matching window.
  var SKIP = { "if": 1, "then": 1, "else": 1, "fi": 1, "env": 1, "exec": 1, "sh": 1, "bash": 1, "test": 1, "-c": 1 };
  // The program behind a wrapper: 'env VAR=1 prog', 'sh -c "... prog ..."'.
  // Its picture and its documentation are the program's, not env's or sh's.
  function realCommand(act) {
    var w = act.split(/\s+/), k;
    for (k = 0; k < w.length; k++) {
      var t = w[k].replace(/^["']+|["';]+$/g, "").replace(/^.*\//, "");
      if (SKIP[t] || /=/.test(t) || !/^[A-Za-z][\w.+-]*$/.test(t)) continue;
      return t;
    }
    return w[0].replace(/^.*\//, "");
  }
  function program(act) {
    var m = act.match(/copal-install\s+(\S+)/);
    if (m) return { kind: "install", cmd: m[1] };
    m = act.match(/-e\s+sh\s+-c\s+'(\S+)\s+--help/);
    if (m) return { kind: "help", cmd: m[1] };
    m = act.match(/^(?:foot|kitty|alacritty|xterm|urxvt)\s+-e\s+(.*)$/);
    if (m) return { kind: "term", cmd: realCommand(m[1]) };
    return { kind: "run", cmd: realCommand(act) };
  }
  window.CopalMenus.program = program;

  // layer: the desktop element to draw into. desk: { launch(item), shot(cmd) }.
  window.CopalMenus.keys = function (D, layer, desk) {
    var ROWS = 17;
    var refs = D.refs || {};

    function el(tag, cls, text) {
      var e = document.createElement(tag);
      if (cls) e.className = cls;
      if (text != null) e.textContent = text;
      return e;
    }

    // ----- the list, as items_for() reads it -----
    var sections = {}, cur = "";
    sections[""] = [];
    D.textmenu.split("\n").forEach(function (line) {
      if (!line) return;
      var m = line.match(/^\^tag\((.*)\)$/);
      if (m) { cur = m[1]; sections[cur] = sections[cur] || []; return; }
      if (line === "^sep()") return;
      m = line.match(/^\^sep\((.*)\)$/);
      if (m) { sections[cur].push({ label: RULE + " " + m[1] + " " + RULE, act: "^sep" }); return; }
      var i = line.indexOf(",");
      sections[cur].push({ label: i < 0 ? line : line.slice(0, i), act: i < 0 ? "" : line.slice(i + 1) });
    });

    // The site's own pages: a branch built the way copal-menu builds a
    // category, reached from the top of both panes.
    if (D.pages && D.pages.length) {
      sections.site = [{ label: "<  Back", act: "^back()" }, { label: RULE + " This site " + RULE, act: "^sep" }]
        .concat(D.pages.map(function (p) { return { label: p.title, act: "^page(" + p.page + ")", desc: p.desc }; }));
      var into = { label: "This site  >", act: "^checkout(site)" };
      sections[""].unshift(into);
      if (sections.apps) sections.apps.splice(1, 0, into);
    }

    // ----- the menu -----
    var menu = el("div", "tm-menu");
    menu.hidden = true;
    menu.setAttribute("role", "dialog");
    menu.setAttribute("aria-label", "copal-menu (Super+Space, Super+Z)");
    var head = el("div", "tm-head");
    head.innerHTML = '<svg width="18" height="18" viewBox="0 0 16 16" aria-hidden="true"><circle cx="6.5" cy="6.5" r="4.8" fill="none" stroke="#c49a52" stroke-width="1.7"/><path d="M10 10l4.2 4.2" stroke="#c49a52" stroke-width="1.9" stroke-linecap="round"/></svg>';
    var prompt = el("span", "tm-prompt"), query = el("span", "tm-q"), caret = el("span", "tm-caret");
    head.appendChild(prompt); head.appendChild(query); head.appendChild(caret);
    var rowsBox = el("div", "tm-rows");
    menu.appendChild(head); menu.appendChild(rowsBox);
    rowsBox.addEventListener("mouseleave", function () { edgeStop(); });
    rowsBox.addEventListener("wheel", function (e) {
      e.preventDefault();
      var n = shown().length, dir = e.deltaY > 0 ? 1 : -1;
      var top = Math.max(0, Math.min(S.top + 3 * dir, n - ROWS));
      if (top === S.top) return;
      S.top = top;
      S.sel = Math.max(S.top, Math.min(S.sel, S.top + ROWS - 1));
      paint();
    }, { passive: false });
    layer.appendChild(menu);

    var card = el("div", "sim-peek tm-card");
    var cshot = el("div", "shot"), ccap = el("div", "cap");
    card.appendChild(cshot); card.appendChild(ccap);
    layer.appendChild(card);

    // ----- state -----
    var S = { tag: "apps", q: "", sel: 0, top: 0, open: false };

    function items() { return sections[S.tag] || []; }
    function shown() {
      var q = S.q.toLowerCase();
      return q ? items().filter(function (r) { return r.label.toLowerCase().indexOf(q) >= 0; }) : items();
    }
    function promptText() {
      if (S.tag === "apps") return "[ Applications ]   System  >";
      if (S.tag === "") return "<  Applications   [ System ]";
      var t = items().filter(function (r) { return r.act === "^sep"; })[0];
      return "<  Back   [ " + (t ? t.label.slice(3, -3) : S.tag) + " ]";
    }

    // Scrolling by the edges, as the real menus now do: hover selects and never
    // moves the list; resting on the first or the last visible row moves it one
    // row at a time, at a steady pace, and the rows between stay put. The wheel
    // moves it too.
    var edgeT = 0, edgeDir = 0;
    function edgeStop() { if (edgeT) clearInterval(edgeT); edgeT = 0; edgeDir = 0; }
    function edgeMove(dir) {
      var n = shown().length, top = Math.max(0, Math.min(S.top + dir, n - ROWS));
      if (top === S.top) return false;
      S.top = top;
      S.sel = dir > 0 ? S.top + ROWS - 1 : S.top;   // the row under the resting pointer
      paint();
      return true;
    }
    function edgeAt(dir) {
      if (dir === edgeDir) return;
      edgeStop(); edgeDir = dir;
      if (dir) edgeT = setInterval(function () { if (!edgeMove(dir)) edgeStop(); }, 140);
    }

    function paint() {
      prompt.textContent = S.q ? "" : promptText();
      query.textContent = S.q;
      var v = shown();
      if (S.sel >= v.length) S.sel = Math.max(0, v.length - 1);
      if (S.sel < S.top) S.top = S.sel;
      if (S.sel >= S.top + ROWS) S.top = S.sel - ROWS + 1;
      rowsBox.innerHTML = "";
      v.slice(S.top, S.top + ROWS).forEach(function (r, k) {
        var i = S.top + k, d = el("div", "tm-row" + (i === S.sel ? " on" : ""), r.label);
        d.addEventListener("mousemove", function () {
          if (S.sel !== i) { S.sel = i; paint(); }
          edgeAt(k === 0 ? -1 : (k === ROWS - 1 ? 1 : 0));
        });
        d.addEventListener("click", function (e) { e.stopPropagation(); S.sel = i; activate(); });
        rowsBox.appendChild(d);
      });
      if (!v.length) rowsBox.appendChild(el("div", "tm-row tm-none", "no match"));
      describe(v[S.sel]);
    }

    // The card: what the selected row opens to.
    function describe(r) {
      if (r && r.desc && /^\^page\(/.test(r.act) && S.open) {
        cshot.className = "shot none"; cshot.style.backgroundImage = ""; cshot.innerHTML = "";
        var t = el("div", "tm-man");
        t.appendChild(el("div", "k", "a page of this site"));
        t.appendChild(el("div", "c", r.label));
        t.appendChild(el("div", "p", r.desc));
        cshot.appendChild(t);
        ccap.innerHTML = ""; ccap.appendChild(el("b", null, r.label));
        ccap.appendChild(document.createTextNode(" — Enter opens it as a window."));
        card.classList.add("on");
        return;
      }
      if (!r || r.act === "^sep" || /^\^/.test(r.act) || !S.open) { card.classList.remove("on"); return; }
      var p = program(r.act), shot = desk.shot(p.cmd);
      cshot.className = "shot" + (shot ? "" : " none");
      cshot.style.backgroundImage = shot ? "url(" + shot + ")" : "";
      ccap.innerHTML = "";
      if (shot) {
        cshot.textContent = "";
        ccap.appendChild(el("b", null, r.label));
        ccap.appendChild(document.createTextNode(" — what it opens to, from the gallery."));
      } else {
        cshot.innerHTML = "";
        var t = el("div", "tm-man");
        t.appendChild(el("div", "k", p.kind === "install" ? "not installed yet" : "terminal command"));
        t.appendChild(el("div", "c", "$ " + (p.kind === "install" ? "doas copal-install " + p.cmd : p.cmd)));
        if (refs[p.cmd]) t.appendChild(el("div", "p", refs[p.cmd]));
        cshot.appendChild(t);
        ccap.appendChild(el("b", null, r.label));
        ccap.appendChild(document.createTextNode(refs[p.cmd] ? " — Enter opens its Terminal Guide entry." : " — no picture in the gallery."));
      }
      card.classList.add("on");
    }

    function go(tag) { S.tag = tag; S.q = ""; S.sel = 0; S.top = 0; paint(); }
    function side(dir) {
      if (S.tag === "apps") go("");
      else if (S.tag === "") go("apps");
      else if (dir === "left") {
        var b = items().filter(function (r) { return /^\^(back|checkout)\(/.test(r.act); })[0];
        go(b && /^\^checkout\(/.test(b.act) ? b.act.slice(10, -1) : "");
      } else go("apps");
    }
    function activate() {
      var r = shown()[S.sel];
      if (!r || r.act === "^sep") return;
      if (/^\^checkout\(/.test(r.act)) return go(r.act.slice(10, -1));
      if (r.act === "^back()") return go("");
      var pg = r.act.match(/^\^page\((.*)\)$/);
      if (pg) { close(); desk.launch({ page: pg[1] }); return; }
      var p = program(r.act);
      close();
      desk.launch({ name: r.label, cmd: p.cmd, kind: p.kind });
    }

    // Super+Space opens the Applications pane; Super+Z the System one.
    function open(pane) {
      S.open = true; menu.hidden = false; head.classList.add("focus");
      go(pane === "system" ? "" : "apps");
    }
    function close() {
      S.open = false; menu.hidden = true; card.classList.remove("on"); head.classList.remove("focus"); edgeStop();
    }

    menu.addEventListener("click", function (e) { e.stopPropagation(); });
    head.addEventListener("click", function (e) {
      // The two tabs in the prompt: the half you click is the pane you get.
      var r = head.getBoundingClientRect();
      side((e.clientX - r.left) < r.width / 2 ? "left" : "right");
    });

    function key(e) {
      if (!S.open) return false;
      if (e.ctrlKey || e.metaKey || e.altKey) return false;
      var v = shown();
      switch (e.key) {
        case "Escape": close(); break;
        case "ArrowDown": S.sel = Math.min(S.sel + 1, v.length - 1); paint(); break;
        case "ArrowUp": S.sel = Math.max(S.sel - 1, 0); paint(); break;
        case "PageDown": S.sel = Math.min(S.sel + ROWS, v.length - 1); paint(); break;
        case "PageUp": S.sel = Math.max(S.sel - ROWS, 0); paint(); break;
        case "ArrowLeft": side("left"); break;
        case "ArrowRight": side("right"); break;
        case "Enter": activate(); break;
        case "Backspace": S.q = S.q.slice(0, -1); S.sel = 0; S.top = 0; paint(); break;
        default:
          if (e.key.length !== 1) return false;
          S.q += e.key; S.sel = 0; S.top = 0; paint();
      }
      return true;
    }

    return {
      open: open, close: close, key: key,
      isOpen: function () { return S.open; },
      toggle: function (pane) { if (S.open) close(); else open(pane); }
    };
  };
})();
