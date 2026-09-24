// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson -- part of Copal Linux. Run by tools/desk-check/desk-check.sh.
// Phase 3: the site's pages in both menus.
(function () {
  var out = [], wait = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
  function ok(name, cond, extra) { out.push((cond ? "PASS " : "FAIL ") + name + (extra ? "  (" + extra + ")" : "")); }
  function wins() { return [].slice.call(document.querySelectorAll(".desk-win")); }
  function shownRows() { return [].slice.call(document.querySelectorAll(".sim-app")).filter(function (r) { return r.style.display !== "none"; }); }
  function key(k) { document.dispatchEvent(new KeyboardEvent("keydown", { key: k, bubbles: true })); }
  // A visitor who has already begun: the menu must not open by itself in the
  // middle of these checks as the panel comes into view.
  document.getElementById("desk").dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
  (async function () {
    await wait(1200);
    document.querySelector(".desk-menu").click();
    var sec = [].slice.call(document.querySelectorAll(".sim-sec")).filter(function (r) { return r._name === "Copal"; })[0];
    ok("copal-gui has a Copal section", !!sec);
    sec.click();
    var rows = shownRows();
    ok("it lists every page of the site", rows.length === window.COPAL_MENU.pages.length, rows.length + " rows");
    ok("each marked as a page", rows.every(function (r) { return r.querySelector(".t") && r.querySelector(".t").textContent === "page"; }));
    [].slice.call(document.querySelectorAll(".sim-sec")).filter(function (r) { return r._name === "All Applications"; })[0].click();
    ok("All Applications is programs only", shownRows().every(function (r) { return !r._app.page; }));
    "installer".split("").forEach(key);
    ok("search finds a page", shownRows()[0] && shownRows()[0]._app.page === "install", shownRows()[0] && shownRows()[0]._app.name);
    key("Enter"); await wait(1200);
    ok("Enter opens it as a window", location.hash === "#page/install" && document.querySelector(".sim-menu").hidden, location.hash);
    document.querySelector(".desk-menu.keys").click();
    var first = [].slice.call(document.querySelectorAll(".tm-row"))[1];
    ok("copal-menu's Applications pane offers This site", first && first.textContent === "This site  >", first && first.textContent);
    first.click();
    var labels = [].slice.call(document.querySelectorAll(".tm-row")).map(function (r) { return r.textContent; });
    ok("…a branch with Back, a heading and the pages", labels[0] === "<  Back" && labels.indexOf("The Terminal Guide") > 0, labels.slice(0, 3).join(" | "));
    key("ArrowDown"); key("ArrowDown");     // past Back and the heading, onto About Copal
    var card = document.querySelector(".tm-card");
    ok("the card says what a page is", card.classList.contains("on") && card.textContent.indexOf("a page of this site") >= 0, card.textContent.slice(0, 50));
    [].slice.call(document.querySelectorAll(".tm-row")).filter(function (r) { return r.textContent === "The Terminal Guide"; })[0].click();
    await wait(1500);
    ok("a click opens the page as a window", location.hash === "#page/commands", location.hash);
    ok("its title is the page's own", wins()[wins().length - 1].querySelector(".name").textContent.indexOf("Terminal Guide") >= 0, wins()[wins().length - 1].querySelector(".name").textContent);
    out.forEach(function (l, i) { fetch("/verdict/" + i + "/" + encodeURIComponent(l)).catch(function () {}); });
  })().catch(function (e) { fetch("/verdict/0/" + encodeURIComponent("ERROR " + e)); });
})();
