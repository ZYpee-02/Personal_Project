import { randomUUID } from 'node:crypto';

export class InputError extends Error {}

export function validateEvent(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new InputError('An event object is required.');
  if (input.type === 'join') {
    if (typeof input.username !== 'string' || !/^[A-Za-z0-9_]{3,20}$/.test(input.username)) {
      throw new InputError('Use a Roblox username with 3–20 letters, numbers, or underscores.');
    }
    return { type: 'join', username: input.username };
  }
  if (input.type === 'vote') {
    if (typeof input.viewer !== 'string' || !/^[A-Za-z0-9_.:@-]{1,100}$/.test(input.viewer)) {
      throw new InputError('A stable viewer ID is required (letters, digits, _, ., :, @, or -).');
    }
    if (!['ward', 'sail'].includes(input.choice)) throw new InputError('Choose ward or sail.');
    const result = { type: 'vote', viewer: input.viewer, choice: input.choice };
    if (input.username !== undefined) result.username = validateEvent({ type: 'join', username: input.username }).username;
    return result;
  }
  if (input.type === 'blessing') {
    if (!['bloom', 'aurora', 'giant'].includes(input.kind)) throw new InputError('Unknown blessing.');
    return { type: 'blessing', kind: input.kind };
  }
  if (input.type === 'gift') {
    const username = validateEvent({ type: 'join', username: input.username }).username;
    const kind = validateEvent({ type: 'blessing', kind: input.kind }).kind;
    if (!Number.isInteger(input.count) || input.count < 1 || input.count > 20) throw new InputError('Gift count must be from 1 to 20.');
    return { type: 'gift', username, kind, count: input.count };
  }
  if (input.type === 'follow') {
    const viewer = validateEvent({ type: 'vote', viewer: input.viewer, choice: 'ward' }).viewer;
    return { type: 'follow', viewer };
  }
  throw new InputError('Choose join, vote, blessing, gift, or follow.');
}

// Test events exist only in memory. A single optional Roblox server consumes them.
export class EventStore {
  constructor({ file, now = Date.now, maxPending = 200, ttlMs = 120_000 } = {}) {
    if (file) throw new Error('File persistence is disabled in this test bridge.');
    this.now = now;
    this.maxPending = maxPending;
    this.ttlMs = ttlMs;
    this.events = [];
    this.lastPollAt = null;
    this.lastAckAt = null;
    this.receipts = [];
    this.prune();
  }

  prune() {
    const kept = this.events.filter(event => this.now() - event.createdAt < this.ttlMs);
    this.events = kept;
  }

  push(input) {
    const payload = validateEvent(input);
    this.prune();
    if (this.events.length >= this.maxPending) throw new InputError('The queue is full. Connect the game or wait for stale events to expire.');
    const event = { ...payload, id: randomUUID(), createdAt: this.now() };
    this.events.push(event);
    return event;
  }

  poll() {
    this.prune();
    this.lastPollAt = this.now();
    return this.events.slice(0, 20);
  }

  ack(results) {
    if (!Array.isArray(results) || results.length > 20 || results.some(result =>
      !result || typeof result.id !== 'string' || !['applied', 'rejected'].includes(result.status)
      || typeof result.message !== 'string' || result.message.length > 240)) {
      throw new InputError('Provide up to 20 event results with id, status, and message.');
    }
    const pending = new Set(this.events.map(event => event.id));
    const accepted = results.filter(result => pending.has(result.id));
    const ids = new Set(accepted.map(result => result.id));
    this.events = this.events.filter(event => !ids.has(event.id));
    this.receipts = [...accepted.map(result => ({ ...result, at: this.now() })), ...this.receipts].slice(0, 30);
    this.lastAckAt = this.now();
    return ids.size;
  }

  status() {
    this.prune();
    return { pending: this.events.length, lastPollAt: this.lastPollAt, lastAckAt: this.lastAckAt, receipts: this.receipts };
  }
}
