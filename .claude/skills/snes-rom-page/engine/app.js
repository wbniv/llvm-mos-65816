/*
 * bsnes-jg-wasm loader — drives our Emscripten build of bsnes-jg 2.1.0 (the exact
 * core the llvm-mos-65816 differential gate trusts). Boots a .sfc, renders the
 * core's framebuffer to a <canvas>, maps the keyboard to an SNES pad, and runs an
 * in-browser fidelity self-check that reproduces the gate's headless WRAM assert.
 *
 * The core module (web/cores/bsnes_jg.js) is built by ./build.sh. No libretro,
 * no EmulatorJS — just Module._bjg_* calls.
 */
(function () {
  "use strict";

  // An embedding page (e.g. the indri.studio inline embed) can point the loader
  // at assets under a base path and pick the boot ROM; defaults reproduce the
  // standalone page (relative paths, the zoom demo).
  var BASE = (window.BJG_BASE || "");
  var DEFAULT_ROM = (window.BJG_DEFAULT_ROM || "mandel-display");

  // Content-hash cache-busting. The page (fresh HTML) injects window.BJG_BUST: a map of
  // relative asset path -> short SHA of that file's bytes. bust() appends "?v=<sha>" so each
  // asset can be cached immutably forever, yet a re-synced file (same filename, new content =
  // new sha) gets a NEW url and is re-fetched — no stale ROM after a deploy. Absent map (older
  // embed) -> plain path, so it still works.
  function bust(path) {
    var b = window.BJG_BUST;
    return BASE + path + (b && b[path] ? "?v=" + b[path] : "");
  }

  // SNES controller bits — must match Bsnes::Input::Gamepad in src/bsnes.hpp.
  var JOY = {
    B: 1 << 15, Y: 1 << 14, Select: 1 << 13, Start: 1 << 12,
    Up: 1 << 11, Down: 1 << 10, Left: 1 << 9, Right: 1 << 8,
    A: 1 << 7, X: 1 << 6, L: 1 << 5, R: 1 << 4
  };
  // Keyboard -> pad. Z/X = B/A, A/S = Y/X (the common SNES-on-keyboard layout).
  var KEYMAP = {
    ArrowUp: JOY.Up, ArrowDown: JOY.Down, ArrowLeft: JOY.Left, ArrowRight: JOY.Right,
    KeyZ: JOY.B, KeyX: JOY.A, KeyA: JOY.Y, KeyS: JOY.X,
    Enter: JOY.Start, ShiftRight: JOY.Select, ShiftLeft: JOY.Select,
    KeyQ: JOY.L, KeyW: JOY.R
  };

  var Module = null;       // the instantiated Emscripten module
  var manifest = null;     // roms/manifest.json
  var current = null;      // current rom id
  var pad = 0;             // port-0 button mask
  var running = false;     // RAF loop active
  var rafId = 0;
  var imageData = null;
  var runLabel = "";       // status prefix for the running ROM
  var dimsShown = false;   // whether status already carries WxH
  var revealed = false;    // true once the first non-black live frame has been drawn
                           //  (until then the baked preview stays on the canvas)

  var canvas = document.getElementById("screen");
  var ctx = canvas.getContext("2d", { alpha: false });
  var statusEl = document.getElementById("status");
  var checkEl = document.getElementById("checkresult");
  var bannerEl = document.getElementById("banner");

  function status(msg) { if (statusEl) statusEl.textContent = msg; }

  // --- core module loading ---------------------------------------------------

  function loadCoreScript() {
    return new Promise(function (resolve, reject) {
      if (window.BsnesJg) return resolve(window.BsnesJg);
      var s = document.createElement("script");
      s.src = bust("cores/bsnes_jg.js");
      s.onload = function () { resolve(window.BsnesJg); };
      s.onerror = function () { reject(new Error("core not built")); };
      document.body.appendChild(s);
    });
  }

  // --- rendering -------------------------------------------------------------

  function present() {
    var w = Module._bjg_video_w(), h = Module._bjg_video_h(), pitch = Module._bjg_video_pitch();
    if (!w || !h) return;
    // bsnes hands us a 512-wide buffer for lores content (256 logical px doubled)
    // and ~240 scanlines incl. overscan. Collapse the 2x horizontal doubling and
    // crop to the 224 visible NTSC lines — the true 256x224 logical frame, square
    // pixels at the SNES 8:7 aspect (matches the gate's jgxcheck PNG). Without
    // this the picture is stretched 2x wide.
    var step = w >= 512 ? 2 : 1;
    var ow = (w / step) | 0;
    var yoff = h >= 232 ? 8 : 0;             // skip the top NTSC overscan (active picture starts at line 8)
    var avail = h - yoff;
    var oh = avail < 224 ? avail : 224;
    var heap = Module.HEAPU32;               // re-fetch each frame (may grow)
    var base = Module._bjg_video() >>> 2;    // uint32 index
    // Hold the baked preview until the SNES emits its first non-black frame: mandel-display
    // force-blanks (solid black) while it computes pass 1, and drawing those boot frames
    // would flash the preview to black for ~0.3 s before the first coarse image lands.
    // Sample a sparse grid — a revealed Mandelbrot lights up far more than one in 64 pixels.
    if (!revealed) {
      var lit = false;
      for (var sy = yoff; sy < yoff + oh && !lit; sy += 8) {
        var sb = base + sy * pitch;
        for (var sx = 0; sx < ow; sx += 8)
          if (heap[sb + sx * step] & 0xffffff) { lit = true; break; }
      }
      if (!lit) return;                      // still blank — leave the preview up
      revealed = true;
    }
    if (!imageData || canvas.width !== ow || canvas.height !== oh) {
      canvas.width = ow; canvas.height = oh;
      imageData = ctx.createImageData(ow, oh);
    }
    if (!dimsShown && runLabel) { status(runLabel + " · " + ow + "×" + oh); dimsShown = true; }
    var out = imageData.data;
    var di = 0;
    for (var y = 0; y < oh; y++) {
      var si = base + (y + yoff) * pitch;
      for (var x = 0; x < ow; x++) {
        var px = heap[si + x * step];        // 0x00RRGGBB
        out[di++] = (px >>> 16) & 0xff;      // R
        out[di++] = (px >>> 8) & 0xff;       // G
        out[di++] = px & 0xff;               // B
        out[di++] = 255;                     // A
      }
    }
    ctx.putImageData(imageData, 0, 0);
  }

  function frame() {
    if (!running) return;
    Module._bjg_set_input(0, pad);
    Module._bjg_run();
    present();
    rafId = requestAnimationFrame(frame);
  }

  function startLoop() {
    if (running) return;
    running = true;
    rafId = requestAnimationFrame(frame);
  }
  function stopLoop() {
    running = false;
    if (rafId) cancelAnimationFrame(rafId);
    rafId = 0;
  }

  // --- ROM loading -----------------------------------------------------------

  function loadRomBytes(bytes) {
    var ptr = Module._malloc(bytes.length);
    Module.HEAPU8.set(bytes, ptr);
    var ok = Module._bjg_load(ptr, bytes.length);
    Module._free(ptr);
    return ok === 1;
  }

  function playUrl(id) {
    current = id;
    stopLoop();
    if (checkEl) { checkEl.textContent = ""; checkEl.className = "badge"; }
    markActive(id);
    status("loading " + id + ".sfc…");
    return fetch(bust("roms/" + id + ".sfc"))
      .then(function (r) { if (!r.ok) throw new Error("fetch " + id); return r.arrayBuffer(); })
      .then(function (buf) {
        if (!loadRomBytes(new Uint8Array(buf))) throw new Error("core rejected ROM");
        runLabel = "running " + id + ".sfc"; dimsShown = false;
        status(runLabel);
        startLoop();
        updateCheckButton(id);
      })
      .catch(function (e) { status("error: " + e.message); });
  }

  function playFile(file) {
    current = null;
    stopLoop();
    if (checkEl) { checkEl.textContent = ""; checkEl.className = "badge"; }
    document.querySelectorAll("#picker button[data-rom]").forEach(function (b) {
      b.removeAttribute("aria-current");
    });
    status("loading " + file.name + "…");
    file.arrayBuffer().then(function (buf) {
      if (!loadRomBytes(new Uint8Array(buf))) { status("error: core rejected " + file.name); return; }
      runLabel = "running " + file.name; dimsShown = false;
      status(runLabel);
      startLoop();
      updateCheckButton(null);
    });
  }

  // --- fidelity self-check (mirrors dev/jgxcheck.cpp) ------------------------

  function romMeta(id) {
    if (!manifest || !id) return null;
    return manifest.roms.find(function (r) { return r.id === id; }) || null;
  }

  function updateCheckButton(id) {
    var btn = document.getElementById("verify");
    if (!btn) return;
    var meta = romMeta(id);
    if (meta && meta.selfcheck) {
      btn.disabled = false;
      btn.title = "Reproduce the gate's headless assert in this tab";
    } else {
      btn.disabled = true;
      btn.title = "No gate reference for this ROM";
    }
  }

  // Power on, run `frames` frames, then read WRAM and compare — exactly what the
  // gate's jgxcheck does. Runs in chunks so the tab stays responsive.
  function verify() {
    var meta = romMeta(current);
    if (!meta || !meta.selfcheck) return;
    var sc = meta.selfcheck;
    var off = Number(sc.off), len = sc.len, want = Number(sc.want), total = sc.frames;

    stopLoop();
    // re-load this ROM to power on cleanly, like the gate's harness.
    fetch(bust("roms/" + current + ".sfc"))
      .then(function (r) { return r.arrayBuffer(); })
      .then(function (buf) {
        loadRomBytes(new Uint8Array(buf));
        checkEl.className = "badge running";
        var done = 0;
        function chunk() {
          var n = Math.min(120, total - done);
          for (var i = 0; i < n; i++) Module._bjg_run();
          done += n;
          checkEl.textContent = "verifying… " + done + "/" + total + " frames";
          present();
          if (done < total) { setTimeout(chunk, 0); return; }
          // read `len` little-endian bytes of WRAM at `off`
          var wram = Module._bjg_wram() >>> 0;
          var u8 = Module.HEAPU8;
          var got = 0;
          for (var k = 0; k < len; k++) got |= u8[wram + off + k] << (8 * k);
          got >>>= 0;
          var hexGot = "0x" + got.toString(16).toUpperCase();
          var hexWant = "0x" + (want >>> 0).toString(16).toUpperCase();
          if (got === want) {
            checkEl.className = "badge pass";
            checkEl.textContent = "✓ FIDELITY " + hexGot + " == gate (" + sc.label + ", " + total + " frames)";
          } else {
            checkEl.className = "badge fail";
            checkEl.textContent = "✗ MISMATCH got " + hexGot + " want " + hexWant;
          }
          // resume the live demo from the verified state (frame `total`, image
          // already on screen) rather than a fresh black power-on.
          startLoop();
        }
        setTimeout(chunk, 0);
      });
  }

  // --- input -----------------------------------------------------------------

  function onKey(down) {
    return function (e) {
      var bit = KEYMAP[e.code];
      if (bit === undefined) return;
      e.preventDefault();
      if (down) pad |= bit; else pad &= ~bit;
    };
  }

  // --- UI wiring -------------------------------------------------------------

  function markActive(id) {
    document.querySelectorAll("#picker button[data-rom]").forEach(function (b) {
      b.setAttribute("aria-current", b.dataset.rom === id ? "true" : "false");
    });
  }

  function showProvenance() {
    fetch(bust("cores/PROVENANCE.json"))
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (p) {
        if (!p || !bannerEl) return;
        var emver = (String(p.emscripten || "").match(/\d+\.\d+\.\d+/) || ["?"])[0];
        bannerEl.innerHTML =
          "Running <b>" + p.core + " " + p.version + "</b> — the exact cycle-accurate core " +
          "the differential gate trusts (sha256 <code>" + String(p.sha256).slice(0, 12) +
          "…</code>, emscripten " + emver + "). Hit <b>Verify fidelity</b> to reproduce the " +
          "gate's headless WRAM assert in this tab.";
      })
      .catch(function () {});
  }

  // Pause the run loop when the canvas scrolls out of view (resume on return),
  // so an embedded demo doesn't burn a CPU core while the reader is elsewhere.
  function observeVisibility() {
    var target = document.getElementById("game") || canvas;
    if (!target || typeof IntersectionObserver === "undefined") return;
    new IntersectionObserver(function (entries) {
      if (entries[0].isIntersecting) {
        if (Module && Module._bjg_loaded && Module._bjg_loaded()) startLoop();
      } else {
        stopLoop();
      }
    }, { threshold: 0.05 }).observe(target);
  }

  // Paint the baked coarse preview onto the canvas right away, so a recognizable fractal
  // (not a black box) shows while the ~3.9 MB core downloads and the ROM force-blanks through
  // its first compute pass. Replaced by the live framebuffer on the first non-black frame
  // (see `revealed` in present()). Only mandel-display ships an asset; any ROM without a
  // preview/<id>.png just 404s the image and shows the default black — no error path needed.
  function paintPreview(id) {
    if (!id || !ctx) return;
    var img = new Image();
    img.onload = function () {
      if (revealed) return;                  // live already took over
      ctx.imageSmoothingEnabled = false;     // crisp nearest-neighbour upscale (the SNES look)
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    };
    img.src = bust("preview/" + id + ".png");
  }

  function init() {
    // The picker, file input, verify button and drag-drop target are all
    // optional — an embed may render just the canvas + status. Guard each.
    document.querySelectorAll("#picker button[data-rom]").forEach(function (b) {
      b.addEventListener("click", function () { playUrl(b.dataset.rom); });
    });
    var fileEl = document.getElementById("file");
    if (fileEl) fileEl.addEventListener("change", function (e) {
      if (e.target.files[0]) playFile(e.target.files[0]);
    });
    var verifyEl = document.getElementById("verify");
    if (verifyEl) verifyEl.addEventListener("click", verify);
    window.addEventListener("keydown", onKey(true));
    window.addEventListener("keyup", onKey(false));
    var game = document.getElementById("game");
    if (game) {
      ["dragover", "drop"].forEach(function (ev) {
        game.addEventListener(ev, function (e) { e.preventDefault(); });
      });
      game.addEventListener("drop", function (e) {
        if (e.dataTransfer.files[0]) playFile(e.dataTransfer.files[0]);
      });
    }

    // Show the baked preview before anything loads (covers the core download + ROM boot).
    var bootRom = new URLSearchParams(location.search).get("rom") || DEFAULT_ROM;
    paintPreview(bootRom);

    status("loading core…");
    Promise.all([
      loadCoreScript().then(function (factory) {
        return factory({ locateFile: function (p) {           // bust the wasm Emscripten loads
          return (p && p.slice(-5) === ".wasm") ? bust("cores/" + p) : p;
        }});
      }),
      fetch(bust("roms/manifest.json")).then(function (r) { return r.json(); })
    ]).then(function (res) {
      Module = res[0];
      window.__bjg = Module;     // exposed for debugging / automated checks
      manifest = res[1];
      showProvenance();
      observeVisibility();
      playUrl(bootRom);
    }).catch(function (e) {
      status("");
      if (bannerEl) {
        bannerEl.innerHTML =
          "<b>Core not built.</b> Run <code>build.sh</code> to compile " +
          "<code>bsnes_jg.{js,wasm}</code>, then reload. (" + e.message + ")";
        bannerEl.className = "banner warn";
      }
    });
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
