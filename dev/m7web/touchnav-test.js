// dev/m7web/touchnav-test.js — nav-chevron plan steps 2–4 harness for the web player's manifest-driven
// touch navigation (chevron hit rectangles, the guaranteed 120 ms pulse, and its cancellation surfaces).
//
// Run against any copy of the player (site checkout, node_modules package, or a live download):
//   node dev/m7web/touchnav-test.js ~/biohack.net/public/play/app.js
//   curl -fsSL https://indri.studio/apps/llvm-mos-65816/play/app.js -o /tmp/app.js && node dev/m7web/touchnav-test.js /tmp/app.js
// Exit 0 = ALL PASS. No dependencies (node >= 20).
//
// Brace-matched EXTRACTION of the shipped clearTouchNav(), touchNavBitAt() and the canvas "pointerdown"
// handler out of the given app.js, evaluated in a vm context against DOM stubs with fake timers. It
// re-implements nothing: the code under test is the shipped text. Static wiring checks cover the two
// surfaces that funnel through stopLoop(), plus the scope assertion behind the 2026-09-14 indri.studio
// freeze (clearTouchNav closure-scoped but called from stopLoop -> ReferenceError on every boot).
'use strict';
const fs = require('fs');
const vm = require('vm');
const src = fs.readFileSync(process.argv[2], 'utf8');

function braceBlock(startIdx) {           // return src slice from startIdx through the matching '}'
  const open = src.indexOf('{', startIdx);
  let depth = 0;
  for (let i = open; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') { depth--; if (depth === 0) return src.slice(startIdx, i + 1); }
  }
  throw new Error('unbalanced braces from ' + startIdx);
}
function fnText(name) {
  const i = src.indexOf('function ' + name + '(');
  if (i < 0) throw new Error('function ' + name + ' not found');
  return braceBlock(i);
}
const pdIdx = src.indexOf('canvas.addEventListener("pointerdown", function (e)');
if (pdIdx < 0) throw new Error('pointerdown handler not found');
const pdHandler = braceBlock(src.indexOf('function (e)', pdIdx));   // "function (e) { ... }"
const joyText = braceBlock(src.indexOf('var JOY = ') + 'var JOY = '.length);

// ---- vm context: DOM stubs + fake timers ----------------------------------------------------
let now = 0; const timers = [];
const ctx = {
  console,
  setTimeout: (fn, ms) => { const id = timers.length + 1; timers.push({ id, at: now + ms, fn }); return id; },
  clearTimeout: (id) => { const t = timers.find((x) => x.id === id); if (t) t.fn = null; },
};
vm.createContext(ctx);
const listeners = { canvas: {}, window: {} };
ctx.canvas = { width: 256, height: 224, getBoundingClientRect: () => ({ left: 0, top: 0, width: 256, height: 224 }),
  addEventListener: (ev, fn) => { listeners.canvas[ev] = fn; } };
ctx.window = { addEventListener: (ev, fn) => { listeners.window[ev] = fn; } };
ctx.document = { getElementById: () => null };
vm.runInContext(`
  var JOY = ${joyText};
  var pad = 0, touchRelease = 0, touchNavPressed = 0;
  var current = 'lzss-gallery';
  var TN = { left: [0, 70, 24, 24], right: [232, 70, 24, 24] };
  function romMeta() { return { touchNav: TN }; }
  ${fnText('clearTouchNav')}
  ${fnText('touchNavBits')}
  ${fnText('touchNavBitAt')}
  var pointerdown = ${pdHandler};
  canvas.addEventListener("pointerdown", pointerdown, { passive: false });
  canvas.addEventListener("pointercancel", clearTouchNav);
  window.addEventListener("blur", clearTouchNav);
`, ctx);
const g = (name) => vm.runInContext(name, ctx);
const advance = (ms) => { now += ms; for (const t of timers) if (t.fn && t.at <= now) { const f = t.fn; t.fn = null; f(); } };
const down = (x, y) => { let prevented = false; listeners.canvas.pointerdown({ clientX: x, clientY: y, preventDefault: () => { prevented = true; } }); return prevented; };

let fails = 0;
function check(label, got, want) { const ok = got === want; if (!ok) fails++; console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}  got=${got} want=${want}`); }
const JOY = g('JOY');

// ---- step 2: hit rectangles at edges and outside ----------------------------------------------
const bitAt = (x, y) => vm.runInContext(`touchNavBitAt(TN, ${x}, ${y})`, ctx);
check('hitrect left  top-left corner   (0,70)', bitAt(0, 70), JOY.Left);
check('hitrect left  bottom-right in   (23,93)', bitAt(23, 93), JOY.Left);
check('hitrect left  just right of     (24,70)', bitAt(24, 70), 0);
check('hitrect left  just below        (0,94)', bitAt(0, 94), 0);
check('hitrect left  just above        (0,69)', bitAt(0, 69), 0);
check('hitrect right top-left corner   (232,70)', bitAt(232, 70), JOY.Right);
check('hitrect right bottom-right in   (255,93)', bitAt(255, 93), JOY.Right);
check('hitrect right just left of      (231,70)', bitAt(231, 70), 0);
check('hitrect right just below        (232,94)', bitAt(232, 94), 0);
check('hitrect centre of canvas        (128,112)', bitAt(128, 112), 0);

// ---- step 3: short click keeps the bit for the 120 ms pulse -----------------------------------
down(244, 82);
check('short click asserts Right immediately', g('pad'), JOY.Right);
check('pointerup listener registered on canvas', !!listeners.canvas.pointerup, false);
if (listeners.canvas.pointerup) listeners.canvas.pointerup({});
check('pad still asserted after immediate pointerup', g('pad'), JOY.Right);
advance(60);
check('pad still asserted at t=60ms (< 120ms pulse)', g('pad'), JOY.Right);
advance(80);
check('pad released at t=140ms (>= 120ms pulse)', g('pad'), 0);
check('pulse ownership cleared', g('touchNavPressed'), 0);

// ---- step 4: cancellation surfaces --------------------------------------------------------------
down(244, 82);
check('pointercancel: asserted before', g('pad'), JOY.Right);
listeners.canvas.pointercancel({});
check('pointercancel clears pad', g('pad'), 0);
check('pointercancel clears ownership', g('touchNavPressed'), 0);
down(12, 82);
check('left chevron asserts Left', g('pad'), JOY.Left);
listeners.window.blur({});
check('blur clears pad', g('pad'), 0);
down(244, 82); g('clearTouchNav()');
check('clearTouchNav() clears pad', g('pad'), 0);
down(244, 82);
check('second pulse: Right only', g('pad'), JOY.Right);
down(12, 82);
check('replacement pulse: Left only (previous direction cleared)', g('pad'), JOY.Left);
advance(200);
check('blur -> clearTouchNav wired', /window\.addEventListener\("blur",\s*clearTouchNav\)/.test(src), true);
check('pointercancel -> clearTouchNav wired', /canvas\.addEventListener\("pointercancel",\s*clearTouchNav\)/.test(src), true);
check('stopLoop() calls clearTouchNav (shutdown)', /clearTouchNav\(\);/.test(fnText('stopLoop')), true);
check('playUrl() (ROM replacement) calls stopLoop', /stopLoop\(\);/.test(fnText('playUrl')), true);
check('playFile() (ROM replacement) calls stopLoop', /stopLoop\(\);/.test(fnText('playFile')), true);
// scope check — the defect behind TODO item A: clearTouchNav must be visible from stopLoop's scope
const clearIdx = src.indexOf('function clearTouchNav('), stopIdx = src.indexOf('function stopLoop(');
check('clearTouchNav defined at player scope (before stopLoop)', clearIdx >= 0 && clearIdx < stopIdx, true);

console.log(fails ? `${fails} FAILED (${process.argv[2]})` : `ALL PASS (${process.argv[2]})`);
process.exit(fails ? 1 : 0);
