// dev/m7web/cdp.mjs — minimal Chrome DevTools Protocol driver over host google-chrome (headless=new).
// Node 22 built-in WebSocket; no npm deps; a cold profile per launch. Lives in THIS repo so the
// website gates of plans 121/123 are reproducible without adding browser tooling to either site repo.
// Note: headless rAF runs at ~11 Hz on this host, so anything driving the SNES player must sample
// by emulated frame count, not wall-clock (see smoke22.mjs).
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export async function launch({ width = 1280, height = 900, extraArgs = [] } = {}) {
  const profile = mkdtempSync(join(tmpdir(), 'cdp-prof-'));   // cold cache every launch
  const args = [
    '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
    `--window-size=${width},${height}`, '--no-first-run', '--no-default-browser-check',
    '--disable-gpu', '--mute-audio', '--autoplay-policy=no-user-gesture-required',
    '--hide-scrollbars', ...extraArgs, 'about:blank',
  ];
  const proc = spawn('google-chrome', args, { stdio: ['ignore', 'ignore', 'pipe'] });
  const wsUrl = await new Promise((res, rej) => {
    let buf = '';
    proc.stderr.on('data', (d) => {
      buf += d.toString();
      const m = buf.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (m) res(m[1]);
    });
    proc.on('exit', (c) => rej(new Error(`chrome exited ${c}\n${buf}`)));
    setTimeout(() => rej(new Error('chrome did not announce DevTools\n' + buf)), 15000);
  });
  const port = new URL(wsUrl).port;
  const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = list.find((t) => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  let id = 0; const pending = new Map(); const listeners = [];
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) { const { res, rej } = pending.get(msg.id); pending.delete(msg.id);
      msg.error ? rej(new Error(msg.error.message)) : res(msg.result); }
    else if (msg.method) listeners.forEach((l) => l(msg.method, msg.params));
  };
  const send = (method, params = {}) => new Promise((res, rej) => {
    const mid = ++id; pending.set(mid, { res, rej }); ws.send(JSON.stringify({ id: mid, method, params }));
  });
  const on = (fn) => listeners.push(fn);
  const evaluate = async (expression) => {
    const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error('page exception: ' + JSON.stringify(r.exceptionDetails.exception?.description || r.exceptionDetails.text));
    return r.result.value;
  };
  const navigate = async (url) => {
    const loaded = new Promise((res) => { const h = (m) => { if (m === 'Page.loadEventFired') res(); }; on(h); });
    await send('Page.navigate', { url });
    await loaded;
  };
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const key = async (keyText, opts = {}) => {
    const map = { Enter: { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, text: '\r' },
                  Escape: { key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 },
                  Tab: { key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 },
                  Space: { key: ' ', code: 'Space', windowsVirtualKeyCode: 32, text: ' ' } };
    const k = { ...map[keyText], ...opts };
    await send('Input.dispatchKeyEvent', { type: 'keyDown', ...k });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', ...k });
  };
  const screenshot = async (path, clip) => {
    const { writeFileSync } = await import('node:fs');
    const r = await send('Page.captureScreenshot', { format: 'png', ...(clip ? { clip: { ...clip, scale: 1 } } : {}) });
    writeFileSync(path, Buffer.from(r.data, 'base64'));
  };
  const close = () => { try { ws.close(); } catch {} proc.on('exit', () => { try { rmSync(profile, { recursive: true, force: true }); } catch {} }); proc.kill('SIGKILL'); };
  await send('Page.enable'); await send('Runtime.enable'); await send('Network.enable');
  await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: width < 600 });
  return { send, on, evaluate, navigate, sleep, key, screenshot, close, version: list[0]?.title };
}
