import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
export function runLua(source) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  try {
    const status = lauxlib.luaL_dostring(L, to_luastring(source));
    assert.equal(status, lua.LUA_OK, status === lua.LUA_OK ? undefined : to_jsstring(lua.lua_tostring(L, -1)));
  } finally { lua.lua_close(L); }
}
