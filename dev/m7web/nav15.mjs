// dev/m7web/nav15.mjs — nav-chevron plan step 15: live mouse + keyboard navigation on a published
// lzss-gallery page (biohack.net or indri.studio), driven by real trusted input in headless Chromium.
//
// Run (needs the cached Playwright — `npx -y playwright@1.62.0 install chromium` once if missing;
// set PLAYWRIGHT_MODULE to its index.mjs if it is not at the path below):
//   node dev/m7web/nav15.mjs https://biohack.net/snes/lzss-gallery/ 'biohack.net (LIVE)'
//   node dev/m7web/nav15.mjs https://indri.studio/apps/llvm-mos-65816/snes/lzss-gallery/ 'indri.studio (LIVE)'
// Pre-deploy check of a site fix (serve the site checkout's play/ dir in place of the live one):
//   node dev/m7web/nav15.mjs <url> <label> --local-play ~/indri.studio/public/apps/llvm-mos-65816/play /apps/llvm-mos-65816/play/
// Options: --modes control,key-right,key-left,click-right,click-left (default: all five).
//
// Signal: the ROM's own counters, read out of WRAM through the player's exposed module
// (window.__bjg._bjg_wram(), the same pointer the fidelity self-check reads):
//   gallery_canceled      @ 0x3f  (u16) — increments once per accepted user navigation (never on auto-advance)
//   gallery_current_asset @ 0x472 (u8)  — index of the work on screen (62 works)
// plus mean canvas luma (the 2026-08-04 record's did-it-navigate signal) as secondary evidence.
// The observation window is EMULATED FRAMES (counted via _bjg_set_input calls, one per core frame),
// not wall-clock: under host load the headless core may run far below 60 fps. Keys are HELD 150 ms
// (page.keyboard.press() is down+up in ~1 ms and the ROM's once-per-NMI latch can miss it).
// Gotchas: docs/agent-handoff.md "Verifying a published web player page headlessly".
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || '/home/will/.npm/_npx/e41f203b7505f1fb/node_modules/playwright/index.mjs');
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const [url, label, ...rest] = process.argv.slice(2);
let localDir = null, localPrefix = null, modes = ['control', 'key-right', 'key-left', 'click-right', 'click-left'];
for (let i = 0; i < rest.length; i++) {
  if (rest[i] === '--local-play') { localDir = rest[++i]; localPrefix = rest[++i]; }
  if (rest[i] === '--modes') modes = rest[++i].split(',');
}
const MIME = { '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.sfc': 'application/octet-stream', '.png': 'image/png' };
const WORKS = 62, BUDGET = 2500; // frames after input (console gate: press@1000 -> index moves @2503)

const browser = await chromium.launch({ headless: true });
const results = [];
for (const mode of modes) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  let served = 0;
  if (localDir) {
    await page.route((u) => u.pathname.startsWith(localPrefix), async (route) => {
      const p = new URL(route.request().url()).pathname.slice(localPrefix.length);
      const f = join(localDir, p);
      if (!existsSync(f)) return route.continue();
      served++;
      const ext = f.slice(f.lastIndexOf('.'));
      await route.fulfill({ status: 200, body: readFileSync(f), headers: { 'content-type': MIME[ext] || 'application/octet-stream' } });
    });
  }
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  const tStart = Date.now();
  await page.goto(url, { waitUntil: 'load' });
  const running = await page.waitForFunction(() => (document.getElementById('status')?.textContent || '').startsWith('running'), null, { timeout: 60000 }).then(() => true).catch(() => false);
  const st = await page.evaluate(() => document.getElementById('status')?.textContent);
  const appSrc = await page.evaluate(() => [...document.scripts].map((s) => s.src).find((s) => /app\.js/.test(s)) || '');
  console.log(`########## ${label} — ${mode}`);
  console.log(`status="${st}" running=${running} pageerrors=${errs.length}${errs.length ? ' ' + JSON.stringify(errs) : ''} localServed=${served} app=${appSrc.replace(/^https?:\/\/[^/]+/, '')}`);
  if (!running) { results.push({ mode, ok: false }); await page.close(); continue; }
  // frame counter: one _bjg_set_input call per core frame
  await page.evaluate(() => { const M = window.__bjg; const o = M._bjg_set_input; window.__frames = 0; M._bjg_set_input = function (p, b) { window.__frames++; return o.call(M, p, b); }; });
  const luma = () => page.evaluate(() => { const c = document.getElementById('screen'); const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data; let s = 0; for (let i = 0; i < d.length; i += 4) s += 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]; return s / (d.length / 4); });
  const wram = () => page.evaluate(() => { const M = window.__bjg; const w = M._bjg_wram() >>> 0; const u = M.HEAPU8; return { canceled: u[w + 0x3f] | (u[w + 0x40] << 8), cur: u[w + 0x472], frames: window.__frames }; });
  // settle: skip the title card (~luma 22) and wait for a decoded artwork to be held still (luma > 40, 4 stable samples)
  let base = 0, stable = 0;
  for (let i = 0; i < 1200 && stable < 4; i++) { await page.waitForTimeout(500); const l = await luma(); if (l > 40 && Math.abs(l - base) < 0.5) stable++; else stable = 0; base = l; }
  const w0 = await wram();
  const fps = (w0.frames / ((Date.now() - tStart) / 1000)).toFixed(1);
  console.log(`settled: baseline luma=${base.toFixed(2)}  canceled=${w0.canceled} current_asset=${w0.cur}  (emulated ${w0.frames} frames in ${((Date.now() - tStart) / 1000).toFixed(0)} s ≈ ${fps} fps)  mode=${mode}`);
  const box = await page.evaluate(() => { const r = document.getElementById('screen').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  const map = (lx, ly) => ({ x: box.x + (lx / 256) * box.w, y: box.y + (ly / 224) * box.h });
  if (mode === 'control') console.log('  (no input — negative control)');
  if (mode === 'key-right') { console.log('  real ArrowRight keypress (held 150 ms)'); await page.keyboard.down('ArrowRight'); await page.waitForTimeout(150); await page.keyboard.up('ArrowRight'); }
  if (mode === 'key-left') { console.log('  real ArrowLeft keypress (held 150 ms)'); await page.keyboard.down('ArrowLeft'); await page.waitForTimeout(150); await page.keyboard.up('ArrowLeft'); }
  if (mode === 'click-right') { const p = map(244, 82); console.log(`  real mouse click at css (${p.x.toFixed(1)}, ${p.y.toFixed(1)}) = logical (244, 82)`); await page.mouse.click(p.x, p.y); }
  if (mode === 'click-left') { const p = map(12, 82); console.log(`  real mouse click at css (${p.x.toFixed(1)}, ${p.y.toFixed(1)}) = logical (12, 82)`); await page.mouse.click(p.x, p.y); }
  const t0 = Date.now(); let maxd = 0, w = w0, cutAt = null;
  const wantCur = mode === 'control' ? null : (mode.endsWith('right') ? (w0.cur + 1) % WORKS : (w0.cur + WORKS - 1) % WORKS);
  while (true) {
    const l = await luma(); maxd = Math.max(maxd, Math.abs(l - base)); w = await wram();
    const moved = w.canceled !== w0.canceled || w.cur !== w0.cur;
    if (moved && !cutAt) cutAt = { frames: w.frames - w0.frames, secs: (Date.now() - t0) / 1000, canceled: w.canceled, cur: w.cur };
    if (mode !== 'control' && cutAt && w.cur !== w0.cur) break; // index moved: done
    if (w.frames - w0.frames >= BUDGET) break;
    await page.waitForTimeout(250);
  }
  const df = w.frames - w0.frames, secs = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(`max |luma - baseline| over ${df} emulated frames (${secs} s) = ${maxd.toFixed(2)}`);
  console.log(`gallery_canceled ${w0.canceled} -> ${w.canceled}   gallery_current_asset ${w0.cur} -> ${w.cur}${cutAt ? `   (first change after ${cutAt.frames} frames / ${cutAt.secs.toFixed(1)} s)` : ''}`);
  let ok;
  if (mode === 'control') { ok = w.canceled === w0.canceled; console.log(`  =>  ${ok ? 'no user cancellation (auto-advance only)' : 'UNEXPECTED cancellation'}  ${ok ? 'PASS' : 'FAIL'}`); }
  else { ok = w.canceled === w0.canceled + 1 && w.cur === wantCur; console.log(`  =>  ${ok ? `CUT (navigated to ${wantCur}, one cancellation)` : `no cut / wrong target (want ${wantCur}, one cancellation)`}  ${ok ? 'PASS' : 'FAIL'}`); }
  results.push({ mode, ok });
  await page.close();
}
await browser.close();
const ok = results.every((r) => r.ok);
console.log(`\n${label}: ${ok ? 'PASS' : 'FAIL'}  ` + results.map((r) => `${r.mode}=${r.ok ? 'ok' : 'FAIL'}`).join(' '));
process.exit(ok ? 0 : 1);
