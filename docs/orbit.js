/* THE ORBIT.
   A single arc with planets on it, drawn to match the taskbar the full level
   installs: the curve is the workspace strip, the lit body is the workspace
   you are on. Computed rather than hand-drawn so it reflows with the page.

   It is decoration, and it behaves like it: aria-hidden, wrapped so any
   failure leaves a blank strip rather than a broken page, and completely
   still when the visitor has asked for reduced motion. */
(function () {
  var c = document.getElementById('orbit');
  if (!c || !c.getContext) return;
  var ctx = c.getContext('2d');
  if (!ctx) return;

  var still = window.matchMedia &&
              window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* Ink does the drawing; amber is only ever a fill. Same rule as the CSS. */
  var KEY = '#121212', RESIN = '#fccf8a', DEEP = '#87704f', COOL = '#565c85';
  var w = 0, h = 0, dpr = 1;

  function size() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    w = c.clientWidth; h = c.clientHeight;
    c.width = Math.round(w * dpr); c.height = Math.round(h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  /* The arc: a shallow bezier across the full width, bowing down. Points on
     it are read back with the standard cubic parameterisation, which is what
     lets the bodies sit ON the curve instead of near it. */
  function pt(t) {
    var x0 = 0, y0 = h * 0.30, x1 = w * 0.5, y1 = h * 1.05, x2 = w, y2 = h * 0.30;
    var u = 1 - t;
    return { x: u * u * x0 + 2 * u * t * x1 + t * t * x2,
             y: u * u * y0 + 2 * u * t * y1 + t * t * y2 };
  }

  function draw(now) {
    ctx.clearRect(0, 0, w, h);

    /* The curve itself, faint -- it is a rail, not a subject. */
    ctx.strokeStyle = KEY; ctx.globalAlpha = .55; ctx.lineWidth = 1;
    ctx.beginPath();
    for (var i = 0; i <= 60; i++) {
      var p = pt(i / 60);
      i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y);
    }
    ctx.stroke();
    ctx.globalAlpha = 1;

    /* Five bodies -- five workspaces, which is what the i3 config actually
       defines. The third is "active": larger, lit, and flaring. */
    var drift = still ? 0 : Math.sin(now / 3400) * 0.012;
    for (var n = 0; n < 5; n++) {
      var t = 0.12 + n * 0.19 + drift;
      var q = pt(t);
      var active = (n === 2);
      var r = active ? 11 : 5.5;

      if (active) {
        /* Flares: the theme grows them on the workspace you are on. Slow,
           and frozen flat when motion is not wanted. */
        var beat = still ? 1 : 1 + Math.sin(now / 900) * 0.12;
        var glow = ctx.createRadialGradient(q.x, q.y, r * 0.6, q.x, q.y, r * 4.6 * beat);
        glow.addColorStop(0, 'rgba(252,207,138,0.85)');
        glow.addColorStop(1, 'rgba(252,207,138,0)');
        ctx.fillStyle = glow;
        ctx.beginPath(); ctx.arc(q.x, q.y, r * 4.6 * beat, 0, Math.PI * 2); ctx.fill();

        ctx.strokeStyle = KEY; ctx.globalAlpha = .8; ctx.lineWidth = 1;
        for (var f = 0; f < 8; f++) {
          var a = (f / 8) * Math.PI * 2 + (still ? 0 : now / 7000);
          ctx.beginPath();
          ctx.moveTo(q.x + Math.cos(a) * (r + 4), q.y + Math.sin(a) * (r + 4));
          ctx.lineTo(q.x + Math.cos(a) * (r + 9 * beat), q.y + Math.sin(a) * (r + 9 * beat));
          ctx.stroke();
        }
        ctx.globalAlpha = 1;
      }

      ctx.beginPath(); ctx.arc(q.x, q.y, r, 0, Math.PI * 2);
      ctx.fillStyle = active ? RESIN : COOL;
      ctx.globalAlpha = active ? 1 : .55; ctx.fill();
      ctx.globalAlpha = 1;
      /* The black stroke is the whole look: an engraved disc, not a dot. */
      ctx.strokeStyle = KEY; ctx.lineWidth = active ? 2 : 1; ctx.stroke();
    }

    if (!still) requestAnimationFrame(draw);
  }

  function boot() { size(); requestAnimationFrame(draw); }

  window.addEventListener('resize', function () {
    size(); if (still) draw(0);
  });

  /* The face is loaded before first paint where the browser supports it, so
     the wordmark never flashes in a fallback serif. */
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(boot);
  else boot();
})();
