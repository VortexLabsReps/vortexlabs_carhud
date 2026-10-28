// Ejecuta una prueba Lua en una VM Lua 5.3 (fengari) con el entorno simulado de dev/fivem.lua.
// Uso: node dev/run.js <prueba.lua>
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const file = path.resolve(__dirname, process.argv[2]);
const root = path.resolve(__dirname, '..').split(path.sep).join('/');

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_pushstring(L, to_luastring(root));
lua.lua_setglobal(L, to_luastring('FD_ROOT'));
// Lectura de archivos reales del recurso (p. ej. locales/*.json) para el LoadResourceFile simulado.
lua.lua_pushjsfunction(L, (state) => {
  const name = lua.lua_tojsstring(state, 1);
  try { lua.lua_pushstring(state, to_luastring(require('fs').readFileSync(name, 'utf8'))); } catch { lua.lua_pushnil(state); }
  return 1;
});
lua.lua_setglobal(L, to_luastring('FD_READ'));
if (lauxlib.luaL_dofile(L, to_luastring(file)) !== 0) {
  console.log('ERROR', lua.lua_tojsstring(L, -1));
  process.exit(1);
}
