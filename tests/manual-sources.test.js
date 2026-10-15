import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const luaparse = require('luaparse');
const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const files = [
  ['Config', 'ModuleScript', 'ServerScriptService/Config.lua'],
  ['RealmState', 'ModuleScript', 'ServerScriptService/RealmState.lua'],
  ['World', 'ModuleScript', 'ServerScriptService/World.lua'],
  ['Realm', 'Script', 'ServerScriptService/Realm.server.lua'],
  ['Realm', 'LocalScript', 'StarterPlayerScripts/Realm.client.lua'],
];

test('all three server requires resolve to the documented sibling ModuleScripts', () => {
  const server = read('roblox/ServerScriptService/Realm.server.lua');
  const dependencies = [...server.matchAll(/require\(script\.Parent\.(\w+)\)/g)].map(match => match[1]);
  assert.deepEqual(dependencies, ['Config', 'RealmState', 'World']);
  for (const name of dependencies) {
    const entry = files.find(([scriptName, kind]) => scriptName === name && kind === 'ModuleScript');
    assert.ok(entry, `Missing sibling ModuleScript: ${name}`);
    const parsed = luaparse.parse(read(`roblox/${entry[2]}`), { luaVersion: '5.3' });
    assert.equal(parsed.body.at(-1).type, 'ReturnStatement');
    assert.equal(parsed.body.at(-1).arguments.length, 1);
  }
  const client = read('roblox/StarterPlayerScripts/Realm.client.lua');
  assert.doesNotMatch(client, /\brequire\s*\(/);
  for (const remote of ['Snapshot', 'Action', 'Notice']) {
    assert.ok(client.includes(`WaitForChild("${remote}")`));
    assert.ok(server.includes(`= "${remote}", remotes`));
  }
  assert.ok(client.includes('WaitForChild("Riftbound")'));
  assert.ok(server.includes('"Riftbound", ReplicatedStorage'));
});

test('manual guide contains the five complete raw source files without serialization', () => {
  execFileSync('python3', ['scripts/build_manual_guide.py']);
  const guide = read('MANUAL_STUDIO_SETUP.md');
  const blocks = [...guide.matchAll(/```luau\n([\s\S]*?)```/g)].map(match => match[1]);
  assert.equal(blocks.length, 5);
  files.forEach(([name, kind, path], index) => {
    assert.equal(blocks[index], read(`roblox/${path}`), path);
    assert.doesNotThrow(() => luaparse.parse(blocks[index], { luaVersion: '5.3' }), path);
    assert.ok(guide.includes(`**${kind}** named **${name}**`));
  });
});

test('standard build no longer generates or bundles Command Bar code', () => {
  const pkg = JSON.parse(read('package.json'));
  assert.doesNotMatch(pkg.scripts.build, /build_studio_installer|lua_strings/);
  assert.ok(!existsSync(new URL('../scripts/build_studio_installer.py', import.meta.url)));
  assert.ok(!existsSync(new URL('../INSTALL_IN_STUDIO.txt', import.meta.url)));
  assert.doesNotMatch(read('scripts/build_bundle.py'), /INSTALL_IN_STUDIO/);
});
