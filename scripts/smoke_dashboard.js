// Optional real-browser smoke test, no browser automation dependency required.
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { createServer } from '../bridge/server.js';
import { EventStore } from '../bridge/events.js';

const profile = mkdtempSync(join(tmpdir(), 'riftbound-browser-'));
const gameToken = 'browser-test-game-token-12345678901234567890';
const store = new EventStore();
const server = createServer({ store, gameToken });
let chrome, socket;
let nextId = 0;
const pending = new Map();
const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

function cdp(method, params = {}) {
  const id = ++nextId;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 12_000);
    pending.set(id, { resolve: value => { clearTimeout(timer); resolve(value); }, reject: error => { clearTimeout(timer); reject(error); } });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const result = await cdp('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
  return result.result.value;
}
async function until(check, label) {
  for (let i = 0; i < 80; i++) { if (await check()) return; await delay(100); }
  throw new Error(`Timed out: ${label}`);
}

try {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  chrome = spawn(process.env.CHROMIUM || 'chromium', [
    '--headless', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
    '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0',
    `--user-data-dir=${profile}`, '--window-size=1440,1200', 'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  const debugAddress = await new Promise((resolve, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error('Chromium did not start. Set CHROMIUM to a supported browser binary.')), 12_000);
    chrome.on('error', error => { clearTimeout(timer); reject(error); });
    chrome.on('exit', code => { clearTimeout(timer); reject(new Error(`Chromium exited: ${code}`)); });
    chrome.stderr.on('data', chunk => {
      output = (output + chunk.toString()).slice(-12000);
      const match = output.match(/DevTools listening on ws:\/\/([^/]+)/);
      if (match) { clearTimeout(timer); resolve(`http://${match[1]}`); }
    });
  });
  const tabs = await (await fetch(`${debugAddress}/json/list`)).json();
  socket = new WebSocket(tabs.find(tab => tab.type === 'page').webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  const exceptions = [];
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.method === 'Runtime.exceptionThrown') exceptions.push(message.params.exceptionDetails.text);
    const request = pending.get(message.id);
    if (request) { pending.delete(message.id); message.error ? request.reject(new Error(message.error.message)) : request.resolve(message.result); }
  });
  await cdp('Page.enable');
  await cdp('Runtime.enable');
  await cdp('Page.navigate', { url: base });
  await until(() => evaluate("document.querySelector('#connection-state')?.textContent === 'Waiting for your sky island'"), 'dashboard initial status');
  await evaluate("document.querySelector('#username').value = 'Roblox'; document.querySelector('#arrival-form').requestSubmit();");
  await until(() => store.events.length === 1, 'arrival form queues an event');
  assert.equal(store.events[0].username, 'Roblox');
  const response = await fetch(`${base}/api/game/events`, { headers: { Authorization: `Bearer ${gameToken}` } });
  const { events } = await response.json();
  await fetch(`${base}/api/game/ack`, { method: 'POST', headers: { Authorization: `Bearer ${gameToken}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ results: [{ id: events[0].id, status: 'applied', message: 'Roblox arrived through the star gate.' }] }) });
  await until(() => evaluate("document.querySelector('#journal').textContent.includes('Roblox arrived through the star gate.')"), 'applied game receipt');
  await evaluate("document.querySelector('[data-blessing=aurora]').click();");
  await until(() => store.events.length === 1, 'blessing button queues an event');
  assert.equal(store.events[0].kind, 'aurora');
  await evaluate("document.querySelector('#vote-form button[value=sail]').click();");
  await until(() => store.events.length === 2, 'vote form queues an event');
  assert.deepEqual({ type: store.events[1].type, choice: store.events[1].choice, viewer: store.events[1].viewer }, { type: 'vote', choice: 'sail', viewer: 'traveler-01' });
  const rejected = store.events[1];
  store.ack([{ id: rejected.id, status: 'rejected', message: 'Voting opens when the rift awakens.' }]);
  await until(() => evaluate("document.querySelector('#journal .event-rejected')?.textContent.includes('Voting opens')"), 'rejected vote receipt');
  mkdirSync('dist', { recursive: true });
  const desktop = await cdp('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
  writeFileSync('dist/dashboard-desktop.png', Buffer.from(desktop.data, 'base64'));
  await cdp('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await delay(250);
  assert.ok(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), 'mobile layout must not overflow horizontally');
  const mobile = await cdp('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
  writeFileSync('dist/dashboard-mobile.png', Buffer.from(mobile.data, 'base64'));
  assert.deepEqual(exceptions, [], 'no uncaught browser JavaScript errors');
  console.log('Browser smoke passed: arrival, blessing, vote, applied/rejected receipts, mobile layout. Screenshots saved to dist/.');
} finally {
  if (socket) socket.close();
  for (const request of pending.values()) request.reject(new Error('Browser test ended.'));
  if (chrome && chrome.exitCode === null) {
    const exited = new Promise(resolve => chrome.once('exit', resolve));
    chrome.kill('SIGTERM');
    await Promise.race([exited, delay(2000)]);
    if (chrome.exitCode === null) { chrome.kill('SIGKILL'); await exited; }
  }
  await new Promise(resolve => server.close(resolve));
  rmSync(profile, { recursive: true, force: true, maxRetries: 4, retryDelay: 200 });
}
