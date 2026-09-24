// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson -- part of Copal Linux. Run by tools/desk-check/desk-check.sh.
// Screenshots only: open a menu on its Copal pages, from ?menu=gui or ?menu=keys.
(function () {
  // A screenshot is taken at once: nothing may be caught halfway through a fade.
  var st = document.createElement("style"); st.textContent = "*{transition:none!important}"; document.head.appendChild(st);
  var m = (location.search.match(/menu=(\w+)/) || [])[1];
  function key(k) { document.dispatchEvent(new KeyboardEvent("keydown", { key: k, bubbles: true })); }
  if (m === "gui") {
    document.querySelector(".desk-menu").click();
    [].slice.call(document.querySelectorAll(".sim-sec")).filter(function (r) { return r._name === "Copal"; })[0].click();
    var row = [].slice.call(document.querySelectorAll(".sim-app")).filter(function (r) { return r._app.page === "commands"; })[0];
    row.dispatchEvent(new MouseEvent("mousemove", { bubbles: true }));
  } else if (m === "split") {
    document.querySelector(".desk-menu").click();
    [].slice.call(document.querySelectorAll(".sim-app")).filter(function (r) { return r._app.name === "Brogue"; })[0].click();
  } else if (m === "keys") {
    document.querySelector(".desk-menu.keys").click();
    [].slice.call(document.querySelectorAll(".tm-row"))[1].click();
    for (var i = 0; i < 9; i++) key("ArrowDown");
  }
})();
