import http from 'node:http';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { EventStore, InputError } from './events.js';

const publicDir = fileURLToPath(new URL('./public/', import.meta.url));
const pages = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
]);

function matchesToken(header, expected) {
  const actual = Buffer.from(typeof header === 'string' ? header : '');
  const wanted = Buffer.from(`Bearer ${expected}`);
  return actual.length === wanted.length && timingSafeEqual(actual, wanted);
}

async function readBody(request) {
  if (request.headers['content-type']?.split(';')[0].trim() !== 'application/json') {
    throw new InputError('Send application/json.');
  }
  let length = 0;
  const chunks = [];
  for await (const chunk of request) {
    length += chunk.length;
    if (length > 8192) throw new InputError('Request body is too large.');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new InputError('Invalid JSON.'); }
}

export function createServer({ store, gameToken, adminToken = '', logger = console }) {
  if (!gameToken || gameToken.length < 24) throw new Error('A game token of at least 24 characters is required.');
  return http.createServer(async (request, response) => {
    const send = (status, data) => {
      response.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
      response.end(JSON.stringify(data));
    };
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('Content-Security-Policy', "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
    try {
      const path = new URL(request.url, 'http://bridge.invalid').pathname;
      if (request.method === 'GET' && pages.has(path)) {
        const [file, type] = pages.get(path);
        response.writeHead(200, { 'content-type': type, 'cache-control': 'no-store' });
        response.end(readFileSync(resolve(publicDir, file)));
        return;
      }
      if (!path.startsWith('/api/')) { send(404, { error: 'Not found.' }); return; }
      // Browsers may only call APIs from this origin; no permissive CORS.
      const origin = request.headers.origin;
      if (origin && new URL(origin).host !== request.headers.host) { send(403, { error: 'Origin is not allowed.' }); return; }
      const gameRoute = path.startsWith('/api/game/');
      if (gameRoute ? !matchesToken(request.headers.authorization, gameToken)
        : adminToken && !matchesToken(request.headers.authorization, adminToken)) {
        send(401, { error: 'A valid bearer token is required.' }); return;
      }
      if (request.method === 'GET' && path === '/api/status') {
        send(200, { ...store.status(), mode: adminToken ? 'authenticated' : 'local simulator' }); return;
      }
      if (request.method === 'POST' && path === '/api/events') {
        send(201, { event: store.push(await readBody(request)), message: 'Queued. The game must acknowledge this event before it is applied.' }); return;
      }
      if (request.method === 'GET' && path === '/api/game/events') {
        send(200, { events: store.poll() }); return;
      }
      if (request.method === 'POST' && path === '/api/game/ack') {
        const body = await readBody(request);
        send(200, { acknowledged: store.ack(body.results) }); return;
      }
      send(404, { error: 'Not found.' });
    } catch (error) {
      if (error instanceof InputError) send(400, { error: error.message });
      else { logger.error('Bridge request failed:', error.name); send(500, { error: 'Bridge request failed. Check the server logs.' }); }
    }
  });
}

export function start() {
  const host = process.env.HOST || '127.0.0.1';
  const port = Number(process.env.PORT || 8787);
  const adminToken = process.env.ADMIN_TOKEN || '';
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PORT must be between 1 and 65535.');
  if (!['127.0.0.1', 'localhost', '::1'].includes(host) && adminToken.length < 24) {
    throw new Error('A non-loopback HOST requires ADMIN_TOKEN with at least 24 characters. Use HTTPS at your deployment proxy.');
  }
  const stateDir = resolve(process.env.STATE_DIR || '.local');
  mkdirSync(stateDir, { recursive: true, mode: 0o700 });
  const configPath = resolve(stateDir, 'game-config.json');
  let saved = {};
  try { saved = JSON.parse(readFileSync(configPath, 'utf8')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const gameToken = process.env.GAME_TOKEN || saved.gameToken || randomBytes(32).toString('hex');
  if (gameToken.length < 24 || (adminToken && gameToken === adminToken)) throw new Error('Use distinct, strong game and admin tokens.');
  writeFileSync(configPath, JSON.stringify({ gameToken }, null, 2) + '\n', { mode: 0o600 });
  const store = new EventStore();
  const server = createServer({ store, gameToken, adminToken });
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  server.listen(port, host, () => {
    console.log(`Riftbound simulator listening on ${host}:${port}.`);
    console.log('Private game token: .local/game-config.json (or your STATE_DIR). Do not share or commit it.');
    console.log('No TikTok connection is active. Events on this dashboard are simulated.');
    console.log('Game events are memory-only and reset when this process stops.');
  });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { const server = start(); server.on('error', error => { console.error(error.message); process.exitCode = 1; }); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
