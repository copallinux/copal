// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson -- part of Copal Linux. Run by tools/desk-check/desk-check.sh.
(function () {
  var out = [], wait = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
  function ok(name, cond, extra) { out.push((cond ? "PASS " : "FAIL ") + name + (extra ? "  (" + extra + ")" : "")); }
  function wins() { return [].slice.call(document.querySelectorAll(".desk-win")); }
  function last() { var w = wins(); return w[w.length - 1]; }
  // A visitor who has already begun: the menu must not open by itself in the
  // middle of these checks as the panel comes into view.
  document.getElementById("desk").dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
  (async function () {
    await wait(1200);
    location.hash = "#app/rsync"; await wait(1500);
    var w = last();
    ok("a program window fills in its guide entry", w && w.querySelector(".why") && w.querySelector("pre.ex"), w && w.querySelector(".desk-txt").textContent.slice(0, 40));
    ok("a terminal tool is set in foot", w && w.classList.contains("foot"));
    ok("its title bar links the guide and man", w && w.querySelectorAll(".links a").length >= 2);
    w.querySelector('.links a[href="#man/rsync"]').click(); await wait(1500);
    ok("man opens the man page as a window", location.hash === "#man/rsync" && last().querySelector("iframe"), location.hash);
    var mf = last().querySelector("iframe");
    ok("the man page is framed without its nav", mf.contentDocument.documentElement.classList.contains("framed"));
    location.hash = "#app/ssh"; await wait(1500);
    var code = [].slice.call(last().querySelectorAll(".desk-txt a[href^='#app/']"))[0];
    ok("a command named in an entry links to its window", !!code, code && code.getAttribute("href"));
    if (code) { var h = code.getAttribute("href"); code.click(); await wait(1500); ok("…and opens it", location.hash === h, location.hash); }
    location.hash = "#app/copal-bar"; await wait(1500);
    var see = last().querySelectorAll(".see a");
    ok("See also links its neighbours", see.length >= 1, see.length + " links");
    location.hash = "#app/audacity"; await wait(1500);
    ok("a program the guide does not cover still opens", last().querySelector("h2").textContent === "Audacity");
    var d = document.createElement("pre"); d.textContent = out.join("\n"); document.body.appendChild(d);
    out.forEach(function (l, i) { fetch("/verdict/" + i + "/" + encodeURIComponent(l)).catch(function () {}); });
  })().catch(function (e) { fetch("/verdict/0/" + encodeURIComponent("ERROR " + e)); });
})();
