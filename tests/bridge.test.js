import test from 'node:test';
import assert from 'node:assert/strict';
import { EventStore, validateEvent } from '../bridge/events.js';
import { createServer } from '../bridge/server.js';

const gameToken = 'test-game-token-01234567890123456789';
const adminToken = 'test-admin-token-01234567890123456789';

test('event validation rejects invalid usernames, votes, identities and blessings', () => {
  for (const event of [null, [], {}, { type: 'join', username: '../../etc' }, { type: 'join', username: 'ab' },
    { type: 'vote', choice: 'ward' }, { type: 'vote', viewer: 'a', choice: 'win' },
    { type: 'vote', viewer: '<script>', choice: 'ward' }, { type: 'blessing', kind: 'win' }]) {
    assert.throws(() => validateEvent(event));
  }
  assert.deepEqual(validateEvent({ type: 'join', username: 'Traveler_1', id: 'forged', token: 'private' }), { type: 'join', username: 'Traveler_1' });
});

test('future gifts, follows and username-bound votes have explicit validated envelopes', () => {
  assert.deepEqual(validateEvent({ type: 'gift', username: 'Alice', kind: 'giant', count: 2 }), { type: 'gift', username: 'Alice', kind: 'giant', count: 2 });
  assert.deepEqual(validateEvent({ type: 'follow', viewer: 'tiktok:123' }), { type: 'follow', viewer: 'tiktok:123' });
  assert.deepEqual(validateEvent({ type: 'vote', viewer: 'tiktok:123', choice: 'ward', username: 'Alice' }), { type: 'vote', viewer: 'tiktok:123', choice: 'ward', username: 'Alice' });
  for (const count of [0, 21, 1.5, Infinity, '2']) assert.throws(() => validateEvent({ type: 'gift', username: 'Alice', kind: 'bloom', count }));
  assert.throws(() => validateEvent({ type: 'follow', viewer: '<script>' }));
});

test('polls redeliver pending events until acknowledged, with explicit rejected receipts', () => {
  const store = new EventStore();
  const event = store.push({ type: 'vote', viewer: 'viewer:1', choice: 'ward' });
  assert.deepEqual(store.poll(), store.poll());
  assert.equal(store.ack([{ id: 'unknown', status: 'applied', message: 'unknown' }]), 0);
  assert.equal(store.status().pending, 1);
  assert.equal(store.ack([{ id: event.id, status: 'rejected', message: 'Voting is closed.' }]), 1);
  assert.equal(store.poll().length, 0);
  assert.equal(store.status().receipts[0].status, 'rejected');
  assert.equal(store.ack([{ id: event.id, status: 'applied', message: 'duplicate ack' }]), 0);
});

test('stale events expire and the pending queue applies backpressure', () => {
  let now = 1000;
  const store = new EventStore({ now: () => now, maxPending: 1, ttlMs: 100 });
  store.push({ type: 'blessing', kind: 'aurora' });
  assert.throws(() => store.push({ type: 'blessing', kind: 'bloom' }), /full/);
  now = 1100;
  assert.equal(store.poll().length, 0);
  assert.doesNotThrow(() => store.push({ type: 'blessing', kind: 'bloom' }));
});

test('test bridge data resets with a new store and file persistence is refused', () => {
  const store = new EventStore();
  store.push({ type: 'join', username: 'Traveler_1' });
  assert.equal(store.status().pending, 1);
  assert.equal(new EventStore().status().pending, 0);
  assert.throws(() => new EventStore({ file: 'queue.json' }), /persistence is disabled/);
});

test('ack validation refuses malformed receipts without removing pending events', () => {
  const store = new EventStore();
  store.push({ type: 'blessing', kind: 'giant' });
  for (const value of [undefined, {}, [null], [{ id: 'a', status: 'ok', message: 'x' }]]) {
    assert.throws(() => store.ack(value));
    assert.equal(store.status().pending, 1);
  }
});

async function withServer(options, callback) {
  const store = new EventStore();
  const server = createServer({ store, gameToken, ...options });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try { await callback(base, store); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
const jsonHeaders = token => ({ 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) });

test('HTTP lifecycle: operator queues, authenticated game polls, game acknowledges, dashboard sees receipt', async () => {
  await withServer({ adminToken }, async base => {
    let response = await fetch(`${base}/api/events`, { method: 'POST', headers: jsonHeaders(adminToken), body: JSON.stringify({ type: 'join', username: 'Traveler_1' }) });
    assert.equal(response.status, 201);
    const { event } = await response.json();
    response = await fetch(`${base}/api/game/events`, { headers: jsonHeaders(gameToken) });
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).events, [event]);
    response = await fetch(`${base}/api/game/ack`, { method: 'POST', headers: jsonHeaders(gameToken), body: JSON.stringify({ results: [{ id: event.id, status: 'applied', message: 'Traveler_1 arrived.' }] }) });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).acknowledged, 1);
    const status = await (await fetch(`${base}/api/status`, { headers: jsonHeaders(adminToken) })).json();
    assert.equal(status.pending, 0);
    assert.equal(status.receipts[0].message, 'Traveler_1 arrived.');
    assert.ok(status.lastPollAt);
    assert.ok(!JSON.stringify(status).includes(gameToken));
  });
});

test('game and operator credentials are scoped separately', async () => {
  await withServer({ adminToken }, async base => {
    for (const token of [undefined, 'wrong', adminToken]) {
      assert.equal((await fetch(`${base}/api/game/events`, { headers: jsonHeaders(token) })).status, 401);
    }
    for (const token of [undefined, gameToken]) {
      assert.equal((await fetch(`${base}/api/status`, { headers: jsonHeaders(token) })).status, 401);
    }
  });
});

test('local simulation serves dashboard assets but refuses cross-origin, malformed, oversized and unsupported requests', async () => {
  await withServer({}, async base => {
    for (const path of ['/', '/app.js', '/style.css']) {
      const response = await fetch(base + path);
      assert.equal(response.status, 200);
      assert.ok((await response.text()).length > 1000);
      assert.ok(response.headers.get('content-security-policy').includes("default-src 'self'"));
    }
    assert.equal((await fetch(`${base}/api/status`)).status, 200);
    assert.equal((await fetch(`${base}/api/status`, { headers: { Origin: 'https://other.example' } })).status, 403);
    for (const body of ['{', JSON.stringify({ type: 'blessing', kind: 'win' }), ' '.repeat(9000)]) {
      assert.equal((await fetch(`${base}/api/events`, { method: 'POST', headers: jsonHeaders(), body })).status, 400);
    }
    assert.equal((await fetch(`${base}/api/events`, { method: 'POST', body: '{}' })).status, 400);
    assert.equal((await fetch(`${base}/private-config.json`)).status, 404);
    assert.equal((await fetch(`${base}/api/game/events`)).status, 401);
  });
});
