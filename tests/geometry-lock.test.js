import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../roblox/ServerScriptService/World.lua',import.meta.url),'utf8');
const hashes=JSON.parse(readFileSync(new URL('./fixtures/shared-road-geometry.json',import.meta.url),'utf8'));
test('v10 shared course definitions, road meshes, checkpoints and obstacle motion remain byte-identical',()=>{
 for(const [start,end] of [['-- A single road,','local function decoration'],['-- Triangulated road quads','local function gridSlot']]) {
    const slice=source.slice(source.indexOf(start),source.indexOf(end,source.indexOf(start)));
    assert.equal(createHash('sha256').update(slice).digest('hex'),hashes[start],`course geometry was altered: ${start}`);
 }
});
