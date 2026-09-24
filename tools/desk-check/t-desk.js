// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson -- part of Copal Linux. Run by tools/desk-check/desk-check.sh.
// Phase 1: drives the desktop with real clicks and history steps.
(function () {
  var out = [], wait = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
  function ok(name, cond, extra) { out.push((cond ? "PASS " : "FAIL ") + name + (extra ? "  (" + extra + ")" : "")); }
  function wins() { return [].slice.call(document.querySelectorAll(".desk-win")); }
  function onWs(n) { return document.querySelectorAll(".desk-ws")[n - 1].querySelectorAll(".desk-win").length; }
  function app(name) { return [].slice.call(document.querySelectorAll(".sim-app")).filter(function (r) { return r._app.name === name; })[0]; }
  (async function () {
    await wait(1500);
    ok("welcome window at a bare address", wins().length === 1 && location.hash === "#page/about", location.hash);
    ok("welcome window starts smaller", wins()[0].classList.contains("intro"));
    var f = document.querySelector(".desk-win iframe");
    ok("framed page marked html.framed", f && f.contentDocument.documentElement.classList.contains("framed"));
    document.querySelector(".desk-menu").click();
    ok("≡ opens copal-gui", !document.querySelector(".sim-menu").hidden);
    app("Audacity").click();
    ok("clicking a program opens its window, menu closed", wins().length === 2 && document.querySelector(".sim-menu").hidden);
    ok("two windows share workspace 1", onWs(1) === 2);
    ok("the welcome window tiles once it has company", !wins()[0].classList.contains("intro"));
    ok("address follows the new window", location.hash === "#app/audacity", location.hash);
    document.querySelector(".desk-menu").click(); app("btop++").click();
    ok("a third window goes to workspace 2", onWs(2) === 1 && !document.querySelectorAll(".desk-ws")[1].hidden);
    ok("the bar marks both workspaces used", document.querySelectorAll(".sim-ws span.used").length === 2);
    document.querySelector(".desk-menu.keys").click();
    ok("❯_ opens copal-menu", !document.querySelector(".tm-menu").hidden);
    document.querySelector(".desk").click();
    ok("a click on the desktop closes it", document.querySelector(".tm-menu").hidden);
    history.back(); await wait(600);
    ok("Back closes the last window", wins().length === 2 && onWs(2) === 0, "wins=" + wins().length);
    ok("…and returns to its address", location.hash === "#app/audacity", location.hash);
    history.forward(); await wait(600);
    ok("Forward opens it again", wins().length === 3, "wins=" + wins().length);
    history.back(); await wait(400);
    var about = wins()[0].querySelector("iframe").contentDocument;
    about.querySelector('a[href="install.html"]').click(); await wait(1200);
    ok("a link in a page opens that page as a window", location.hash === "#page/install" && wins().length === 3, location.hash);
    wins()[wins().length - 1].querySelector(".shut").click();
    ok("× closes a window", wins().length === 2);
    location.hash = "#page/nosuch"; await wait(300);
    ok("an unknown address opens nothing", wins().length === 2);
    out.forEach(function (l, i) { fetch("/verdict/" + i + "/" + encodeURIComponent(l)).catch(function () {}); });
  })().catch(function (e) { fetch("/verdict/0/" + encodeURIComponent("ERROR " + e)); });
})();
