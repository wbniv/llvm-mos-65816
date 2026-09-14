// dev/m7web/filter123.mjs — plan 123 steps 3–10 driven in real headless Chrome against the live galleries.
// Usage: node filter123.mjs <outdir>
import { launch } from './cdp.mjs';
import { mkdirSync } from 'node:fs';
const outdir = process.argv[2]; mkdirSync(outdir, { recursive: true });
const SITES = {
  biohack: { url: 'https://biohack.net/snes/', card: '.cat-card', wrap: '.gl-wrap' },
  indri:   { url: 'https://indri.studio/apps/llvm-mos-65816/snes/', card: '.gl-card-wrap', wrap: '.gl-wrap' },
};
const J = (o) => JSON.stringify(o);
const state = (card) => `(() => {
  const t = document.querySelector('.gl-mode-toggle'), c = document.querySelector('.gl-mode-count');
  const cards = [...document.querySelectorAll('${card}')];
  return { total: cards.length, visible: cards.filter(x => !x.hidden).length, pressed: t.getAttribute('aria-pressed'),
           ariaLabel: t.getAttribute('aria-label'), count: c.textContent.trim(), url: location.search };
})()`;
const slugs = (card) => `[...document.querySelectorAll('${card}:not([hidden])')].map(x => (x.querySelector('a')||{}).getAttribute('href')||'').map(h => h.replace(/\\/$/,'').split('/').pop()).sort()`;
const clickToggle = `document.querySelector('.gl-mode-toggle').click()`;
const settle = async (b) => { await b.evaluate('new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))'); };

for (const [name, S] of Object.entries(SITES)) {
  const b = await launch({ width: 1280, height: 900 });
  await b.navigate(S.url); await settle(b);
  console.log(`\n=== ${name} — ${S.url} (1280×900) ===`);
  console.log(`STEP3 ${name} ${J(await b.evaluate(state(S.card)))}`);
  await b.evaluate(clickToggle); await settle(b);
  const st4 = await b.evaluate(state(S.card));
  console.log(`STEP4 ${name} ${J(st4)}`);
  console.log(`STEP4 ${name} slugs: ${J(await b.evaluate(slugs(S.card)))}`);
  if (name === 'biohack') {
    // STEP 8 — shelves, with real layout: arrow-nav hidden state vs actual overflow.
    const shelf = `[...document.querySelectorAll('.cat-shelf')].map(s => { const row = s.querySelector('.cat-row'), nav = s.querySelector('.cat-nav');
       return { id: s.id, hidden: s.hidden, n: s.querySelectorAll('.cat-card:not([hidden])').length, scrollLeft: row.scrollLeft,
                overflow: row.scrollWidth > row.clientWidth + 1, navHidden: nav ? nav.hidden : null }; })`;
    const during = await b.evaluate(shelf);
    const vis = during.filter(s => !s.hidden);
    console.log(`STEP8 during ${J({ shelfCount: during.length, hiddenDuring: during.filter(s => s.hidden).length,
      visibleDuring: vis.map(s => ({ id: s.id, n: s.n, scrollLeft: s.scrollLeft, overflow: s.overflow, navHidden: s.navHidden })),
      anyVisibleShelfWithZeroCards: vis.some(s => s.n === 0), anyHiddenShelfWithCards: during.some(s => s.hidden && s.n > 0),
      allScrollLeftZero: vis.every(s => s.scrollLeft === 0), arrowNavConsistent: vis.every(s => s.navHidden === !s.overflow) })}`);
  }
  if (name === 'indri') {
    // STEP 7 — combined category + Mode 7, back to All, and the empty state.
    const chip = (c) => `document.querySelector('.gl-chip[data-cat="${c}"]').click()`;
    console.log(`STEP7 afterMode7 ${J(await b.evaluate(state(S.card)))}`);
    await b.evaluate(chip('fractals')); await settle(b);
    console.log(`STEP7 combined   ${J(await b.evaluate(state(S.card)))}`);
    console.log(`STEP7 combined   slugs: ${J(await b.evaluate(slugs(S.card)))}`);
    await b.evaluate(chip('all')); await settle(b);
    console.log(`STEP7 backToAll  ${J(await b.evaluate(state(S.card)))}`);
    await b.evaluate(chip('ciphers')); await settle(b);
    console.log(`STEP7 emptyState ${J(await b.evaluate(`(() => { const e = document.querySelector('.gl-empty'); const s = ${state(S.card)};
      return { cat: 'ciphers', visible: s.visible, emptyHidden: e.hidden, emptyText: e.textContent.trim(), emptyDisplayed: getComputedStyle(e).display !== 'none',
               controlRowStillThere: !!document.querySelector('.gl-mode-toggle'), pressed: s.pressed, count: s.count }; })()`))}`);
    await b.evaluate(chip('all')); await settle(b);
  }
  await b.evaluate(clickToggle); await settle(b);
  console.log(`STEP6 ${name} ${J(await b.evaluate(state(S.card)))}`);
  if (name === 'biohack') {
    const after = await b.evaluate(`[...document.querySelectorAll('.cat-shelf')].filter(s => s.hidden).length`);
    console.log(`STEP8 after  ${J({ hiddenAfter: after })}`);
  }
  // STEP 5 — cold load with ?mode=7.
  await b.navigate(S.url + '?mode=7'); await settle(b);
  console.log(`STEP5 ${name} ${J(await b.evaluate(state(S.card)))}`);
  // STEP 9 — keyboard: Tab to the toggle, Enter activates, Escape clears and refocuses; focus ring; aria-live; hidden attr.
  await b.navigate(S.url); await settle(b);
  let tabs = 0;
  while (tabs < 60 && !(await b.evaluate(`document.activeElement && document.activeElement.classList.contains('gl-mode-toggle')`))) { await b.key('Tab'); tabs++; }
  const focusInfo = await b.evaluate(`(() => { const t = document.querySelector('.gl-mode-toggle'); const cs = getComputedStyle(t);
    return { tabsToReach: ${tabs}, focused: document.activeElement === t, focusVisible: t.matches(':focus-visible'), outline: cs.outlineStyle + ' ' + cs.outlineWidth + ' ' + cs.outlineColor, outlineOffset: cs.outlineOffset,
             tagName: t.tagName, type: t.getAttribute('type'), pressedInitial: t.getAttribute('aria-pressed') }; })()`);
  await b.key('Enter'); await settle(b);
  const afterEnter = await b.evaluate(`(() => { const t = document.querySelector('.gl-mode-toggle'); const cards = [...document.querySelectorAll('${S.card}')];
    return { pressedAfterKeyActivate: t.getAttribute('aria-pressed'), labelAfterKeyActivate: t.getAttribute('aria-label'), visible: cards.filter(c => !c.hidden).length,
             hiddenAttrUsed: cards.filter(c => c.hasAttribute('hidden')).length === cards.length - cards.filter(c => !c.hidden).length, count: document.querySelector('.gl-mode-count').textContent.trim() }; })()`);
  await b.key('Escape'); await settle(b);
  const afterEsc = await b.evaluate(`(() => { const t = document.querySelector('.gl-mode-toggle');
    return { pressedAfterEscape: t.getAttribute('aria-pressed'), focusReturnedToToggle: document.activeElement === t, countAriaLive: document.querySelector('.gl-mode-count').getAttribute('aria-live'), url: location.search }; })()`);
  console.log(`STEP9 ${name} ${J({ ...focusInfo, ...afterEnter, ...afterEsc })}`);
  b.close();

  // STEP 10 — narrowest supported phone width (320 CSS px), then the same with prefers-reduced-motion forced.
  for (const rm of [false, true]) {
    const n = await launch({ width: 320, height: 640, extraArgs: rm ? ['--force-prefers-reduced-motion'] : [] });
    await n.navigate(S.url); await settle(n);
    const geo = `(() => { const t = document.querySelector('.gl-mode-toggle'), c = document.querySelector('.gl-mode-count'); const tr = t.getBoundingClientRect(), cr = c.getBoundingClientRect();
      return { viewport: innerWidth + 'x' + innerHeight, reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
               toggle: { w: Math.round(tr.width), h: Math.round(tr.height), minHeightOK: tr.height >= 40, touch44OK: tr.width >= 44 && tr.height >= 44 },
               countBelowToggle: cr.top >= tr.bottom - 1, countOnSameLine: (cr.top + cr.height / 2) > tr.top && (cr.top + cr.height / 2) < tr.bottom && cr.left >= tr.right, countOverflowsRight: cr.right > innerWidth + 1,
               pageHorizontalOverflow: document.documentElement.scrollWidth > innerWidth + 1 }; })()`;
    const before = await n.evaluate(geo);
    await n.evaluate(clickToggle); await settle(n);
    const st = await n.evaluate(state(S.card));
    const after = await n.evaluate(geo);
    const extra = name === 'biohack' ? await n.evaluate(`(() => { const v = [...document.querySelectorAll('.cat-shelf')].filter(s => !s.hidden).map(s => { const row = s.querySelector('.cat-row'), nav = s.querySelector('.cat-nav');
        return { overflow: row.scrollWidth > row.clientWidth + 1, navHidden: nav ? nav.hidden : null, scrollLeft: row.scrollLeft }; });
      return { visibleShelves: v.length, arrowNavConsistent: v.every(s => s.navHidden === !s.overflow), allScrollLeftZero: v.every(s => s.scrollLeft === 0) }; })()`) : {};
    await n.evaluate(`document.querySelector('.gl-mode-filter').scrollIntoView({ block: 'center' })`); await settle(n);
    await n.screenshot(`${outdir}/${name}-320${rm ? '-reduced-motion' : ''}-mode7.png`);
    console.log(`STEP10 ${name} ${rm ? 'reduced-motion' : 'motion-ok      '} ${J({ ...after, filterApplied: st.visible, pressed: st.pressed, count: st.count, ...extra, toggleGeomUnchangedByActivation: J(before.toggle) === J(after.toggle) })}`);
    n.close();
  }
}
