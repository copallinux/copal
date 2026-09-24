// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson -- part of Copal Linux. Run by tools/desk-check/desk-check.sh.
// The front page and its desktop: arriving, the cues, tiling, the whole
// screen, addresses. Two loads: the page as a visitor finds it, then the page
// opened at a shared address -- the first load's verdicts kept in
// sessionStorage and reported together with the second's.
(function () {
  var wait = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
  var out = JSON.parse(sessionStorage.getItem("t-desk") || "[]");
  function ok(name, cond, extra) { out.push((cond ? "PASS " : "FAIL ") + name + (extra ? "  (" + extra + ")" : "")); }
  function wins() { return [].slice.call(document.querySelectorAll(".desk-win")); }
  function onWs(n) { return document.querySelectorAll(".desk-ws")[n - 1].querySelectorAll(".desk-win").length; }
  function app(name) { return [].slice.call(document.querySelectorAll(".sim-app")).filter(function (r) { return r._app.name === name; })[0]; }
  var desk = document.getElementById("desk");
  var guiOpen = function () { return !document.querySelector(".sim-menu").hidden; };
  function report() {
    sessionStorage.removeItem("t-desk");
    out.forEach(function (l, i) { fetch("/verdict/" + i + "/" + encodeURIComponent(l)).catch(function () {}); });
  }

  if (/stage=2/.test(location.search)) {
    (async function () {
      await wait(1500);
      ok("a shared address opens the whole-screen desktop", desk.classList.contains("full") && document.documentElement.classList.contains("desk-full"));
      ok("…with that window", wins().length === 1 && location.hash === "#app/brogue", location.hash);
      ok("…and no menu opened over it", !guiOpen());
      report();
    })().catch(function (e) { ok("stage 2", false, String(e)); report(); });
    return;
  }

  (async function () {
    await wait(800);
    ok("the front page is a page: no windows, not the whole screen", wins().length === 0 && !desk.classList.contains("full"));
    ok("the bar's two menu buttons glow", document.querySelectorAll(".desk-menu.pulse").length === 2);
    desk.scrollIntoView({ block: "center" }); await wait(1500);
    ok("scrolled to, copal-gui opens by itself", guiOpen());
    var sel = document.querySelector(".sim-app.on");
    ok("…on a program with its picture showing", sel && sel._app.id === "firefox-esr.desktop" && document.querySelector(".sim-peek.on"), sel && sel._app.name);
    ok("…without taking the keyboard", document.activeElement !== document.querySelector(".sim-search .q"));
    ok("the arrows say what to do", document.querySelector(".desk-cues.on") && document.querySelectorAll(".desk-cues .cue:not([hidden])").length >= 1);
    desk.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
    ok("the first click puts the cues and the glow away", !document.querySelector(".desk-cues.on") && !document.querySelector(".desk-menu.pulse"));
    app("Audacity").click();
    ok("a program opens as a window in the panel, the menu closed", wins().length === 1 && !guiOpen());
    ok("its address follows it", location.hash === "#app/audacity", location.hash);
    document.querySelector(".desk-menu").click();
    [].slice.call(document.querySelectorAll(".sim-sec")).filter(function (r) { return r._name === "Copal"; })[0].click();
    [].slice.call(document.querySelectorAll(".sim-app")).filter(function (r) { return r._app.page === "index"; })[0].click();
    await wait(1500);
    ok("two windows share workspace 1", onWs(1) === 2);
    var about = wins()[1].querySelector("iframe");
    ok("the front page, framed as About, has no second desktop in it",
       about && about.contentDocument.documentElement.classList.contains("framed") && !about.contentDocument.querySelector(".desk"));
    document.querySelector(".desk-menu").click(); app("btop++").click();
    ok("a third window goes to workspace 2", onWs(2) === 1 && !document.querySelectorAll(".desk-ws")[1].hidden);
    ok("the bar marks both workspaces used", document.querySelectorAll(".sim-ws span.used").length === 2);
    document.querySelector(".desk-menu.keys").click();
    ok("❯_ opens copal-menu", !document.querySelector(".tm-menu").hidden);
    desk.click();
    ok("a click on the desktop closes it", document.querySelector(".tm-menu").hidden);
    document.querySelector(".desk-menu.full").click();
    ok("the corner button makes it the whole screen", desk.classList.contains("full") && document.documentElement.classList.contains("desk-full"));
    document.querySelector(".desk-menu.full").click();
    ok("…and back to the page", !desk.classList.contains("full"));
    history.back(); await wait(600);
    ok("Back closes the last window", wins().length === 2 && onWs(2) === 0, "wins=" + wins().length);
    history.forward(); await wait(600);
    ok("Forward opens it again", wins().length === 3, "wins=" + wins().length);
    history.back(); await wait(400);
    about.contentDocument.querySelector('a[href="install.html"]').click(); await wait(1200);
    ok("a link in a page opens that page as a window", location.hash === "#page/install", location.hash);
    wins()[wins().length - 1].querySelector(".shut").click();
    ok("× closes a window", wins().length === 2);
    location.hash = "#page/nosuch"; await wait(300);
    ok("an unknown address opens nothing", wins().length === 2);
    sessionStorage.setItem("t-desk", JSON.stringify(out));
    location.href = location.pathname + "?stage=2#app/brogue";
  })().catch(function (e) { ok("stage 1", false, String(e)); report(); });
})();
