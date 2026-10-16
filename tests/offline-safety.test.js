import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

test('all five game scripts exclude persistence/custom HTTP; optional native avatar loading is guarded', () => {
  execFileSync('python3', ['scripts/build_place.py']);
  const forbidden = /DataStoreService|MemoryStoreService|HttpService|RequestAsync|GetAsync|SetAsync|UpdateAsync|BindToClose|GetUserIdFromName|CreateHumanoidModelFromUserId|loadstring|https?:\/\/|rbxassetid:\/\//i;
  const files = ['dist/RiftboundLive.rbxlx'];
  for (const directory of ['ServerScriptService', 'StarterPlayerScripts']) {
    for (const filename of readdirSync(new URL(`../roblox/${directory}/`, import.meta.url))) {
      if (filename.endsWith('.lua')) files.push(`roblox/${directory}/${filename}`);
    }
  }
  assert.equal(files.length, 6);
  for (const path of files) {
    const artifact = readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
    assert.doesNotMatch(artifact, forbidden, path);
    assert.doesNotMatch(artifact, /\.Source\s*=/, 'game code must not install serialized script sources');
    assert.doesNotMatch(artifact, /BridgeToken|BridgeUrl|LiveBridge|GetDataStore/);
  }
  assert.match(readFileSync(new URL('../roblox/ServerScriptService/Config.lua', import.meta.url), 'utf8'), /PersistenceEnabled = false/);
  const world=readFileSync(new URL('../roblox/ServerScriptService/World.lua',import.meta.url),'utf8');
  assert.match(world,/settings.LoadAvatarAppearances ~= true/);
  assert.match(world,/Players:GetHumanoidDescriptionFromUserIdAsync\(userId\)/);
  assert.match(world,/Players:CreateHumanoidModelFromDescriptionAsync\(description, Enum.HumanoidRigType.R6\)/);
});

test('offline exporter rejects privileged/network APIs and nonlocal require calls', () => {
  execFileSync('python3', ['-c', `
from scripts.offline_sources import audit
bad = ['game:GetService("DataStoreService")', 'game:GetService("HttpService")', 'game:GetService("InsertService")', 'require(1234)', 'require(otherModule)', 'loadstring("code")', 'https://example.com', 'Players:GetUserIdFromNameAsync("Alice")', 'game:GetService("UnlistedService")', 'Players:GetHumanoidDescriptionFromUserIdAsync(1)', 'Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)']
for code in bad:
    try:
        audit(code, 'test')
    except ValueError:
        continue
    raise AssertionError('An unsafe API was not rejected: ' + code)
audit('local State = require(script.Parent.RealmState)', 'local module')
`]);
});
