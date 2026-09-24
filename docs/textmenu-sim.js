/* The other menu: copal-menu, the keyboard's, simulated.
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
 * opens to: the gallery's picture of it, or -- for a terminal command with
 * no picture -- its entry in the command reference.
 *
 * Until you touch it, it plays itself: a search, a category, the Install
 * branch. Any key, click or pointer over it hands it to you.
 */
(function () {
  "use strict";
  var D = window.COPAL_MENU;
  var host = document.getElementById("textmenu-sim");
  if (!D || !host || !D.textmenu) return;

  var W = 1280, H = 800, ROWS = 17, RULE = "──";
  var gallery = {}, site = {}, byExec = {};
  (D.gallery || []).forEach(function (g) { gallery[g] = 1; });
  (D.site || []).forEach(function (g) { site[g] = 1; });
  (D.apps || []).forEach(function (a) { if (a.exec && a.shot) byExec[a.exec] = a.shot; });
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

  // What a row runs, and what it opens to.
  function program(act) {
    var m = act.match(/copal-install\s+(\S+)/);
    if (m) return { kind: "install", cmd: m[1] };
    m = act.match(/-e\s+sh\s+-c\s+'(\S+)\s+--help/);
    if (m) return { kind: "help", cmd: m[1] };
    m = act.match(/^(?:foot|kitty|alacritty|xterm|urxvt)\s+-e\s+(\S+)/);
    if (m) return { kind: "term", cmd: m[1].replace(/^.*\//, "") };
    var w = act.split(/\s+/)[0].replace(/^.*\//, "");
    return { kind: "run", cmd: w };
  }
  function shotFor(cmd) {
    var s = byExec[cmd] || (gallery[cmd] ? cmd : null);
    return s ? { small: "img/gallery/" + s + ".jpg", big: site[s] ? "img/site/" + s + ".jpg" : null } : null;
  }
  function refLink(cmd) { return "commands.html#c-" + encodeURIComponent(cmd); }

  // ----- the stage -----
  var wrap = el("div", "sim-wrap tm-wrap");
  wrap.tabIndex = 0;
  wrap.setAttribute("role", "application");
  wrap.setAttribute("aria-label", "A working copy of copal-menu, the keyboard menu");
  var st = el("div", "sim");
  st.style.backgroundImage = "url(img/menu/wallpaper.jpg)";
  wrap.appendChild(st);

  var bar = el("div", "sim-bar");
  var burger = el("button", null, "≡");
  burger.title = "The menu (Super+Space)";
  var title = el("span", "grow", "");
  var tbar = el("span", "time", "");
  bar.appendChild(burger);
  var ws = el("div", "sim-ws");
  [1, 2, 3, 4, 5].forEach(function (n) { ws.appendChild(el("span", n === 5 ? "on" : "", String(n))); });
  bar.appendChild(ws); bar.appendChild(title); bar.appendChild(tbar);
  st.appendChild(bar);
  function tick() {
    var d = new Date();
    tbar.textContent = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
  }
  tick(); setInterval(tick, 10000);

  var menu = el("div", "tm-menu");
  var head = el("div", "tm-head");
  head.innerHTML = '<svg width="18" height="18" viewBox="0 0 16 16" aria-hidden="true"><circle cx="6.5" cy="6.5" r="4.8" fill="none" stroke="#c49a52" stroke-width="1.7"/><path d="M10 10l4.2 4.2" stroke="#c49a52" stroke-width="1.9" stroke-linecap="round"/></svg>';
  var prompt = el("span", "tm-prompt"), query = el("span", "tm-q"), caret = el("span", "tm-caret");
  head.appendChild(prompt); head.appendChild(query); head.appendChild(caret);
  var rowsBox = el("div", "tm-rows");
  menu.appendChild(head); menu.appendChild(rowsBox);
  st.appendChild(menu);

  var card = el("div", "sim-peek tm-card");
  var cshot = el("div", "shot"), ccap = el("div", "cap");
  card.appendChild(cshot); card.appendChild(ccap);
  st.appendChild(card);

  var run = el("div", "sim-run");
  var runNone = el("div", "none");
  var pill = el("div", "pill"), pillT = el("span"), pillX = el("button", null, "Close  ×");
  pill.appendChild(pillT); pill.appendChild(pillX);
  run.appendChild(runNone); run.appendChild(pill);
  st.appendChild(run);

  var badge = el("div", "tm-badge", "demo — press a key or point here to take over");
  st.appendChild(badge);

  // ----- state -----
  var S = { tag: "apps", q: "", sel: 0, top: 0, open: true, running: false };

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
      d.addEventListener("mousemove", function () { if (S.sel !== i) { S.sel = i; paint(); } });
      d.addEventListener("click", function (e) { e.stopPropagation(); S.sel = i; activate(); });
      rowsBox.appendChild(d);
    });
    if (!v.length) rowsBox.appendChild(el("div", "tm-row tm-none", "no match"));
    describe(v[S.sel]);
  }

  // The card: what the selected row opens to.
  function describe(r) {
    if (!r || r.act === "^sep" || /^\^/.test(r.act) || !S.open) { card.classList.remove("on"); return; }
    var p = program(r.act), shot = shotFor(p.cmd);
    cshot.className = "shot" + (shot ? "" : " none");
    cshot.style.backgroundImage = shot ? "url(" + (shot.big || shot.small) + ")" : "";
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
      if (refs[p.cmd]) {
        ccap.appendChild(document.createTextNode(" — see "));
        var a = el("a", null, "man " + p.cmd);
        a.href = refLink(p.cmd);
        ccap.appendChild(a);
        ccap.appendChild(document.createTextNode(" in the command reference."));
      } else {
        ccap.appendChild(document.createTextNode(" — no picture in the gallery."));
      }
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
    launch(r);
  }

  function launch(r) {
    var p = program(r.act), shot = shotFor(p.cmd);
    close();
    S.running = true;
    run.style.backgroundImage = shot ? "url(" + (shot.big || shot.small) + ")" : "";
    runNone.innerHTML = "";
    if (!shot) {
      var box = el("div", "tm-term");
      var lines = p.kind === "install"
        ? ["$ doas copal-install " + p.cmd, "doas (user) password:", "", "copal-install would add " + p.cmd + " from the catalogue,", "then rebuild both menus so it appears in them."]
        : p.kind === "help"
          ? ["$ " + p.cmd + " --help", "(its help, then a shell in the same window)", "", "-- shell in this directory; Ctrl-D to close --", "$ █"]
          : ["$ " + p.cmd, "(" + (refs[p.cmd] || "a terminal program") + ")"];
      lines.forEach(function (l) { box.appendChild(el("div", null, l)); });
      runNone.appendChild(box);
      if (refs[p.cmd]) {
        var a = el("a", "tm-manlink", "see man " + p.cmd + " →");
        a.href = refLink(p.cmd);
        runNone.appendChild(a);
      }
    }
    pillT.textContent = r.label + (p.kind === "run" ? "" : " — in foot");
    title.textContent = r.label;
    run.classList.add("on");
  }
  function stopRunning() {
    run.classList.remove("on"); S.running = false; title.textContent = ""; open();
  }
  function open() { S.open = true; menu.hidden = false; go("apps"); }
  function close() { S.open = false; menu.hidden = true; card.classList.remove("on"); }

  pillX.addEventListener("click", function (e) { e.stopPropagation(); stopRunning(); });
  run.addEventListener("click", function (e) { if (e.target.tagName !== "A") e.stopPropagation(); });
  burger.addEventListener("click", function (e) {
    e.stopPropagation(); takeOver();
    if (S.running) stopRunning(); else if (S.open) close(); else open();
  });
  menu.addEventListener("click", function (e) { e.stopPropagation(); });
  head.addEventListener("click", function (e) {
    // The two tabs in the prompt: the half you click is the pane you get.
    var r = head.getBoundingClientRect();
    side((e.clientX - r.left) < r.width / 2 ? "left" : "right");
  });
  st.addEventListener("click", function () { if (S.open) close(); });

  function key(k) {
    if (S.running) { if (k === "Escape") stopRunning(); return true; }
    if (!S.open) { if (k === "Enter" || k === " " || k === "Meta") { open(); return true; } return false; }
    var v = shown();
    switch (k) {
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
        if (k.length !== 1) return false;
        S.q += k; S.sel = 0; S.top = 0; paint();
    }
    return true;
  }
  wrap.addEventListener("keydown", function (e) {
    if (e.ctrlKey || e.metaKey && e.key !== "Meta" || e.altKey) return;
    takeOver();
    if (key(e.key)) e.preventDefault();
  });
  wrap.addEventListener("mousedown", function () { takeOver(); if (document.activeElement !== wrap) wrap.focus({ preventScroll: true }); });
  wrap.addEventListener("focus", function () { head.classList.add("focus"); });
  wrap.addEventListener("blur", function () { head.classList.remove("focus"); });

  // ----- the demo: plays itself until you take over -----
  var DEMO = [].concat(
    "wait", "type:chess", "Down", "Down", "wait", "clear",
    "Right", "wait", "find:Games  >", "Enter", "Down", "Down", "Down", "Down", "wait",
    "Left", "find:Install software  >", "Enter", "wait", "find:Internet  >", "Enter", "Down", "Down", "Down", "wait",
    "Left", "Left", "Left", "wait", "type:links", "wait", "Enter", "wait", "wait", "wait", "Escape", "wait"
  );
  var demo = { on: true, i: 0, timer: 0, visible: false };
  function step() {
    if (!demo.on) return;
    if (!demo.visible) { demo.timer = setTimeout(step, 600); return; }
    var s = DEMO[demo.i++ % DEMO.length], wait = 520;
    if (s === "wait") wait = 1100;
    else if (s === "clear") { S.q = ""; S.sel = 0; S.top = 0; paint(); }
    else if (s.indexOf("type:") === 0) {
      var t = s.slice(5), j = 0;
      (function typ() {
        if (!demo.on) return;
        if (j < t.length) { key(t[j++]); demo.timer = setTimeout(typ, 140); }
        else demo.timer = setTimeout(step, 700);
      })();
      return;
    } else if (s.indexOf("find:") === 0) {
      var want = s.slice(5), v = shown();
      for (var n = 0; n < v.length; n++) if (v[n].label === want) { S.sel = n; break; }
      paint();
    } else if (s === "Escape" && S.running) stopRunning();
    else key(s === "Down" ? "ArrowDown" : s === "Up" ? "ArrowUp" : s === "Left" ? "ArrowLeft" : s === "Right" ? "ArrowRight" : s);
    if (demo.i % DEMO.length === 0) { if (S.running) stopRunning(); go("apps"); }
    demo.timer = setTimeout(step, wait);
  }
  function takeOver() {
    if (!demo.on) return;
    demo.on = false; clearTimeout(demo.timer); badge.remove();
    if (S.running) stopRunning();
  }
  wrap.addEventListener("mouseenter", takeOver);
  wrap.addEventListener("touchstart", takeOver, { passive: true });
  if (window.IntersectionObserver) {
    new IntersectionObserver(function (es) { demo.visible = es[0].isIntersecting; }, { threshold: 0.4 }).observe(wrap);
  } else demo.visible = true;
  if (window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches) takeOver();

  // ----- scale -----
  var scale = 1;
  function fit() { scale = wrap.clientWidth / W; st.style.transform = "scale(" + scale + ")"; }
  if (window.ResizeObserver) new ResizeObserver(fit).observe(wrap);
  window.addEventListener("resize", fit);

  host.insertBefore(wrap, host.firstChild);
  var img = host.querySelector("img");
  if (img) img.style.display = "none";
  var hint = host.querySelector(".sim-hint");
  if (hint) hint.hidden = false;
  paint(); fit();
  if (demo.on) demo.timer = setTimeout(step, 900);
})();
