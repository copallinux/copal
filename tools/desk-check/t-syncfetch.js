// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson -- part of Copal Linux. Run by tools/desk-check/desk-check.sh.
// Screenshots only: fetch as a synchronous request, so what a window fetches
// is on screen at the load event, when a headless screenshot is taken.
window.fetch = function (u) {
  var x = new XMLHttpRequest(); x.open("GET", u, false); x.send();
  return Promise.resolve({ ok: x.status === 200, json: function () { return Promise.resolve(JSON.parse(x.responseText)); } });
};
