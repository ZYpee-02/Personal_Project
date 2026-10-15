let adminToken = '';
let feedbackTimer;
const journal = document.querySelector('#journal');
const entries = [];
const receiptIds = new Set();

function feedback(message) {
  const target = document.querySelector('#feedback');
  target.textContent = message;
  clearTimeout(feedbackTimer);
  feedbackTimer = setTimeout(() => { target.textContent = ''; }, 6500);
}

function record(title, message, status = 'queued') {
  entries.unshift({ title, message, status, at: new Date() });
  entries.splice(30);
  journal.replaceChildren(...entries.map(entry => {
    const item = document.createElement('li');
    item.className = `event-${entry.status}`;
    const heading = document.createElement('strong');
    heading.textContent = entry.title;
    const text = document.createElement('p');
    text.textContent = entry.message;
    const time = document.createElement('small');
    time.textContent = `${entry.at.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} · ${entry.status.toUpperCase()}`;
    item.append(heading, text, time);
    return item;
  }));
}

async function api(path, data) {
  const response = await fetch(path, {
    method: data === undefined ? 'GET' : 'POST',
    headers: { ...(data === undefined ? {} : { 'Content-Type': 'application/json' }), ...(adminToken ? { Authorization: `Bearer ${adminToken}` } : {}) },
    body: data === undefined ? undefined : JSON.stringify(data),
    signal: AbortSignal.timeout(8000),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'The bridge could not complete this request.');
  return result;
}

async function refresh() {
  try {
    const status = await api('/api/status');
    const connected = status.lastPollAt !== null && Date.now() - status.lastPollAt < 35_000;
    document.querySelector('#connection-state').textContent = connected ? 'A game server is polling' : 'Waiting for your sky island';
    document.querySelector('#connection-description').textContent = connected
      ? 'Events will appear below when the game reports their results.'
      : 'Use Keeper Tools in Studio for an offline demo, or configure the HTTPS bridge to receive these events.';
    document.querySelector('#connection-dot').className = `status-dot${connected ? '' : ' idle'}`;
    document.querySelector('#pending').textContent = status.pending;
    document.querySelector('#last-poll').textContent = status.lastPollAt === null ? 'Not connected' : `${Math.max(0, Math.floor((Date.now() - status.lastPollAt) / 1000))}s ago`;
    for (const receipt of [...status.receipts].reverse()) {
      if (!receiptIds.has(receipt.id)) {
        receiptIds.add(receipt.id);
        record(receipt.status === 'applied' ? 'The realm answered' : 'The realm declined', receipt.message, receipt.status);
      }
    }
    if (receiptIds.size > 500) receiptIds.clear();
  } catch (error) {
    document.querySelector('#connection-state').textContent = 'Bridge unavailable';
    document.querySelector('#connection-description').textContent = error.message;
    document.querySelector('#connection-dot').className = 'status-dot error';
  }
}

async function send(event, button, label) {
  if (button) button.disabled = true;
  try {
    await api('/api/events', event);
    record(label, 'Queued for the game. This is a simulated event, not a real TikTok interaction.');
    feedback('Event queued. Waiting for the game to apply it.');
    await refresh();
  } catch (error) { feedback(error.message); }
  finally { if (button) button.disabled = false; }
}

document.querySelector('#arrival-form').addEventListener('submit', event => {
  event.preventDefault();
  void send({ type: 'join', username: document.querySelector('#username').value.trim() }, event.submitter, 'A traveler approaches');
});
document.querySelector('#vote-form').addEventListener('submit', event => {
  event.preventDefault();
  const choice = event.submitter?.value || 'ward';
  void send({ type: 'vote', viewer: document.querySelector('#viewer').value.trim(), choice }, event.submitter, `A voice for ${choice}`);
});
for (const button of document.querySelectorAll('[data-blessing]')) {
  button.addEventListener('click', () => { void send({ type: 'blessing', kind: button.dataset.blessing }, button, `${button.textContent} summoned`); });
}
document.querySelector('#authenticate').addEventListener('click', () => {
  adminToken = document.querySelector('#admin-token').value.trim();
  document.querySelector('#admin-token').value = '';
  void refresh();
});
void refresh();
setInterval(() => { void refresh(); }, 4000);
