// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson -- part of Copal Linux. Run by tools/desk-check/desk-check.sh.
// Phase 4: keys, fields, focus and what a screen reader is told.
(function () {
  var out = [], wait = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
  function ok(name, cond, extra) { out.push((cond ? "PASS " : "FAIL ") + name + (extra ? "  (" + extra + ")" : "")); }
  function wins() { return [].slice.call(document.querySelectorAll(".desk-win")); }
  function press(target, key, code, mods) {
    var o = Object.assign({ key: key, code: code, bubbles: true, cancelable: true }, mods || {});
    target.dispatchEvent(new KeyboardEvent("keydown", o));
  }
  function up(target, key, code, mods) {
    target.dispatchEvent(new KeyboardEvent("keyup", Object.assign({ key: key, code: code, bubbles: true }, mods || {})));
  }
  var CA = { ctrlKey: true, altKey: true };
  var guiOpen = function () { return !document.querySelector(".sim-menu").hidden; };
  var keysOpen = function () { return !document.querySelector(".tm-menu").hidden; };
  (async function () {
    await wait(1500);
    press(document, "a", "KeyA", CA);
    ok("Ctrl+Alt+A opens copal-gui", guiOpen());
    var q = document.querySelector(".sim-search .q");
    ok("its search is a real field, and has the focus", q && q.tagName === "INPUT" && document.activeElement === q);
    ok("the list is a listbox of options", document.querySelector("#gui-list[role=listbox] [role=option]") !== null);
    q.value = "audacity"; q.dispatchEvent(new Event("input", { bubbles: true }));
    var sel = document.querySelector(".sim-app.on");
    ok("typing in the field searches", sel && /audacity/i.test(sel.textContent), sel && sel.textContent);
    ok("the field names the selected option", !!sel && q.getAttribute("aria-activedescendant") === sel.id, q.getAttribute("aria-activedescendant"));
    press(q, "Enter", "Enter");
    await wait(300);
    ok("Enter opens it, and the window takes the focus", location.hash.indexOf("#app/") === 0 && document.activeElement === wins()[wins().length - 1], location.hash);
    press(document, "z", "KeyZ", CA);
    ok("Ctrl+Alt+Z opens copal-menu on its System pane", keysOpen() && document.querySelector(".tm-prompt").textContent.indexOf("[ System ]") >= 0, document.querySelector(".tm-prompt").textContent);
    var tq = document.querySelector(".tm-q");
    ok("copal-menu's filter is a real field with the focus", tq.tagName === "INPUT" && document.activeElement === tq);
    press(document, "Escape", "Escape");
    ok("Esc closes it", !keysOpen());
    var n = wins().length;
    press(document, "q", "KeyQ", CA);
    ok("Ctrl+Alt+Q closes the focused window", wins().length === n - 1, n + " -> " + wins().length);
    press(document, "2", "Digit2", CA);
    ok("Ctrl+Alt+2 shows workspace 2", !document.querySelectorAll(".desk-ws")[1].hidden && document.querySelectorAll(".sim-ws span")[1].getAttribute("aria-current") === "true");
    press(document, "1", "Digit1", CA);
    press(document, "Meta", "MetaLeft"); up(document, "Meta", "MetaLeft");
    ok("a tap of Super toggles copal-gui", guiOpen());
    press(document, "Meta", "MetaLeft"); up(document, "Meta", "MetaLeft");
    ok("…and a second tap closes it", !guiOpen());
    press(document, "Meta", "MetaLeft"); press(document, "a", "KeyA", { metaKey: true }); up(document, "Meta", "MetaLeft", { metaKey: false });
    ok("Super+A opens it once, not twice", guiOpen());
    press(document, "Escape", "Escape"); press(document, "Escape", "Escape");
    var f = wins()[0].querySelector("iframe");
    press(f.contentDocument, "a", "KeyA", CA);
    ok("a shortcut pressed inside a framed page reaches the desktop", guiOpen());
    press(document, "Escape", "Escape");
    ok("the bar is a labelled toolbar", document.querySelector(".sim-bar[role=toolbar][aria-label]") !== null);
    ok("a workspace says what is on it", /Workspace 1, \d+ window/.test(document.querySelectorAll(".sim-ws span")[0].getAttribute("aria-label")), document.querySelectorAll(".sim-ws span")[0].getAttribute("aria-label"));
    out.forEach(function (l, i) { fetch("/verdict/" + i + "/" + encodeURIComponent(l)).catch(function () {}); });
  })().catch(function (e) {
    out.push("ERROR " + e + "  (windows: " + wins().map(function (w) { return w.getAttribute("aria-label"); }).join(", ") + ")");
    out.forEach(function (l, i) { fetch("/verdict/" + i + "/" + encodeURIComponent(l)).catch(function () {}); });
  });
})();
