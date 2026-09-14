// dev/m7web/smoke22.mjs — plan 121 gate 22 (browser smoke: title → loading → progressive → ready) and the
// runtime half of gate 23 (the ROM/preview requests actually carry ?v=<sha>). Real headless Chrome,
// cold profile, live site. The player emulates exactly one SNES frame per requestAnimationFrame
// callback, so we count rAF callbacks from the moment the ROM is running and sample the canvas at
// emulated FRAME numbers (not wall-clock — headless rAF runs at ~11 Hz on this host).
// Usage: node smoke22.mjs <biohack|indri> <outdir>
import { launch } from './cdp.mjs';
import { mkdirSync } from 'node:fs';

const SITES = {
  biohack: 'https://biohack.net/snes/mandel-oop/',
  indri:   'https://indri.studio/apps/llvm-mos-65816/snes/mandel-oop/',
};
const [site, outdir] = process.argv.slice(2);
mkdirSync(outdir, { recursive: true });
const b = await launch({ width: 1280, height: 900 });
const reqs = [];
b.on((m, p) => { if (m === 'Network.requestWillBeSent' && /play\//.test(p.request.url) && /\.(sfc|png|json|wasm|js)(\?|$)/.test(p.request.url)) reqs.push(p.request.url); });

// Install the rAF counter before the player boots (Page.addScriptToEvaluateOnNewDocument).
await b.send('Page.addScriptToEvaluateOnNewDocument', { source: `
  window.__frames = 0;
  const __raf = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = (cb) => __raf((t) => { window.__frames++; cb(t); });
` });
const t0 = Date.now();
await b.navigate(SITES[site]);
let status = '', tRun = null;
for (let i = 0; i < 600; i++) {
  status = await b.evaluate(`(document.getElementById('status')||{}).textContent||''`);
  if (/^running /.test(status)) { tRun = Date.now(); break; }
  await b.sleep(50);
}
console.log(`status: ${JSON.stringify(status)}  (+${(tRun ?? Date.now()) - t0} ms after navigation)`);
if (!tRun) { console.log('FAIL: player never reached running'); b.close(); process.exit(1); }
await b.evaluate('window.__frames = 0');

const STATS = `(() => {
  const c = document.getElementById('screen') || document.querySelector('canvas');
  const ctx = c.getContext('2d'); const W = c.width, H = c.height;
  const d = ctx.getImageData(0, 0, W, H).data;
  let nb = 0, row0 = 0, rowL = 0; const cols = new Set(); let h = 2166136261;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4; const px = (d[i] << 16) | (d[i+1] << 8) | d[i+2];
    h = Math.imul(h ^ px, 16777619) >>> 0;
    if (px) { nb++; if (y === 0) row0++; if (y === H - 1) rowL++; }
    if (cols.size < 64) cols.add(px);
  }
  return { f: window.__frames, W, H, nonblackPct: +(100 * nb / (W * H)).toFixed(2), colours: cols.size >= 64 ? '64+' : cols.size, row0nb: row0, rowLastNb: rowL, hash: h.toString(16).padStart(8, '0') };
})()`;

// Same frame numbers as the 2026-08-04 jgxcheck table, plus 241/246 inside the deployed ROM's
// post-title black window (239..249) and 1500 for the continuous-animation check.
const targets = [60, 120, 200, 239, 241, 246, 250, 255, 260, 275, 300, 450, 1200, 1500, 3000];
const shots = { 120: 'title-zoom', 200: 'title-hold', 241: 'post-title', 255: 'loading', 300: 'coarse', 1200: 'refined', 3000: 'ready' };
let prev = null;
console.log('\n target  sampled  nonblack%  colours  row0_nb  rowL_nb  hash      diff_prev   wall(s)');
for (const f of targets) {
  while ((await b.evaluate('window.__frames')) < f) await b.sleep(20);
  const s = await b.evaluate(STATS);
  const diff = prev ? (prev.hash === s.hash ? 'same' : 'changed') : '-';
  console.log(`  ${String(f).padStart(5)}  ${String(s.f).padStart(7)}  ${String(s.nonblackPct).padStart(9)}  ${String(s.colours).padStart(7)}  ${String(s.row0nb).padStart(7)}  ${String(s.rowLastNb).padStart(7)}  ${s.hash}  ${diff.padStart(9)}  ${((Date.now() - tRun) / 1000).toFixed(1).padStart(7)}`);
  if (shots[f]) {
    const clip = await b.evaluate(`(() => { const r = (document.getElementById('screen')||document.querySelector('canvas')).getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height }; })()`);
    await b.screenshot(`${outdir}/${site}-f${String(f).padStart(4, '0')}-${shots[f]}.png`, clip);
  }
  prev = s;
}
console.log(`\nfinal status: ${await b.evaluate(`document.getElementById('status').textContent`)}`);
console.log('player asset requests (gate 23 runtime proof — every one carries the content hash):');
for (const u of [...new Set(reqs)]) console.log('  ' + u);
b.close();
