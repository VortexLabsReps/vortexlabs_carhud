// Comprobación estática del recurso (no la carga FiveM):
//  1. Sintaxis de todos los .lua (luaparse, Lua 5.3 ⊂ CfxLua 5.4).
//  2. Cada llamada a una native existe en la base oficial de FiveM, en el lado
//     correcto (cliente/servidor) y con un número de argumentos posible.
//  3. Sintaxis del JS de la interfaz.
// Uso: node dev/check.js   (descarga la base de natives en dev/.cache la primera vez)
const fs = require('fs');
const path = require('path');
const https = require('https');
const { execFileSync } = require('child_process');
const luaparse = require('luaparse');

const root = path.resolve(__dirname, '..');
const cache = path.join(__dirname, '.cache');
let failures = 0;
const fail = (msg) => { failures += 1; console.log(`FAIL ${msg}`); };

// Funciones que CfxLua proporciona sin ser natives de la base (scheduler, eventos…).
const RUNTIME = new Set([
  'CreateThread', 'Wait', 'SetTimeout', 'Citizen', 'AddEventHandler', 'RegisterNetEvent', 'TriggerEvent',
  'TriggerServerEvent', 'TriggerClientEvent', 'RegisterNUICallback', 'SendNUIMessage', 'Entity', 'Player',
  'AddStateBagChangeHandler', 'GetHashKey', 'exports', 'LocalPlayer', 'GlobalState', 'RegisterCommand',
]);

function lua(name) {
  return name.toLowerCase().split('_').map((p) => p.charAt(0).toUpperCase() + p.slice(1)).join('');
}

function download(url, file) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode !== 200) return reject(new Error(`${url}: ${res.statusCode}`));
      const out = fs.createWriteStream(file);
      res.pipe(out);
      out.on('finish', () => out.close(resolve));
    }).on('error', reject);
  });
}

async function nativesDb() {
  fs.mkdirSync(cache, { recursive: true });
  const files = { gta: 'natives.json', cfx: 'natives_cfx.json' };
  for (const name of Object.values(files)) {
    const file = path.join(cache, name);
    if (!fs.existsSync(file)) {
      try { await download(`https://runtime.fivem.net/doc/${name}`, file); } catch (e) { return null; }
    }
  }
  const db = new Map();
  for (const [origin, name] of Object.entries(files)) {
    const data = JSON.parse(fs.readFileSync(path.join(cache, name), 'utf8'));
    for (const ns of Object.values(data)) {
      for (const n of Object.values(ns)) {
        if (!n.name) continue;
        const side = origin === 'gta' ? 'client' : n.apiset || 'client';
        const entry = { side, params: n.params.length, results: n.results };
        const names = [n.name, ...(n.aliases || [])].filter((x) => x && !x.startsWith('_0x'));
        for (const raw of names) {
          const key = lua(raw.replace(/^_/, ''));
          const list = db.get(key) || [];
          list.push(entry);
          db.set(key, list);
        }
      }
    }
  }
  return db;
}

function luaFiles() {
  const out = [];
  (function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (['node_modules', 'dev', 'web', 'html', 'preview', 'tools', '.cache'].includes(e.name)) continue;
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p); else if (e.name.endsWith('.lua')) out.push(p);
    }
  })(root);
  return out.sort();
}

function sideOf(file) {
  const rel = path.relative(root, file).split(path.sep).join('/');
  if (rel.startsWith('client/') || rel.startsWith('bridge/client/')) return 'client';
  if (rel.startsWith('server/') || rel.startsWith('bridge/server/')) return 'server';
  return 'shared';
}

// Librerías estándar que el cliente de FiveM no expone (sí existen en el servidor).
const CLIENT_MISSING_LIBS = new Set(['os', 'io']);

function collectCalls(ast) {
  const calls = [];
  const libs = [];
  const locals = new Set();
  (function visit(node) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) return node.forEach(visit);
    if (node.type === 'MemberExpression' && node.base && node.base.type === 'Identifier' && CLIENT_MISSING_LIBS.has(node.base.name)) {
      libs.push({ name: `${node.base.name}.${node.identifier.name}`, line: node.loc && node.loc.start.line });
    }
    if (node.type === 'LocalStatement' || node.type === 'LocalFunctionDeclaration') {
      (node.variables || [node.identifier]).forEach((v) => v && v.name && locals.add(v.name));
    }
    if (node.type === 'FunctionDeclaration' && node.identifier && node.identifier.type === 'Identifier') locals.add(node.identifier.name);
    if ((node.type === 'CallExpression' || node.type === 'StringCallExpression' || node.type === 'TableCallExpression')
      && node.base && node.base.type === 'Identifier') {
      calls.push({ name: node.base.name, args: node.arguments ? (node.arguments.length !== undefined ? node.arguments.length : 1) : 1, line: node.loc && node.loc.start.line });
    }
    for (const key of Object.keys(node)) if (key !== 'loc' && key !== 'range') visit(node[key]);
  })(ast);
  return { calls, libs, locals };
}

(async () => {
  const db = await nativesDb();
  if (!db) console.log('AVISO: sin acceso a la base de natives; solo se comprueba la sintaxis');
  const definedGlobals = new Set();
  const parsed = [];

  for (const file of luaFiles()) {
    const rel = path.relative(root, file);
    try {
      const ast = luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.3', locations: true });
      parsed.push({ file, rel, ast });
      console.log(`OK   sintaxis ${rel}`);
    } catch (e) {
      fail(`sintaxis ${rel}: ${e.message}`);
    }
  }

  // os/io no existen en el cliente de FiveM: prohibidos en código cliente y compartido.
  let libUses = 0;
  for (const { file, rel, ast } of parsed) {
    if (sideOf(file) === 'server') continue;
    for (const use of collectCalls(ast).libs) {
      libUses += 1;
      fail(`${rel}:${use.line} ${use.name} no existe en el cliente de FiveM`);
    }
  }
  if (!libUses) console.log('OK   sin os/io en código de cliente ni compartido');

  // Globales definidas por el propio recurso (funciones globales, p. ej. ninguna esperada).
  parsed.forEach(({ ast }) => ast.body.forEach((st) => {
    if (st.type === 'FunctionDeclaration' && st.identifier && st.identifier.type === 'Identifier' && !st.isLocal) definedGlobals.add(st.identifier.name);
  }));

  if (db) {
    let checked = 0;
    for (const { file, rel, ast } of parsed) {
      const side = sideOf(file);
      const { calls, locals } = collectCalls(ast);
      for (const call of calls) {
        const name = call.name;
        if (!/^[A-Z]/.test(name) || locals.has(name) || definedGlobals.has(name) || RUNTIME.has(name)) continue;
        checked += 1;
        const entries = db.get(name);
        if (!entries) { fail(`${rel}:${call.line} native inexistente: ${name}`); continue; }
        const sides = side === 'shared' ? ['client', 'server'] : [side];
        for (const s of sides) {
          const usable = entries.filter((e) => e.side === s || e.side === 'shared');
          if (!usable.length) { fail(`${rel}:${call.line} ${name} no existe en el lado ${s}`); continue; }
          if (!usable.some((e) => call.args <= e.params)) {
            fail(`${rel}:${call.line} ${name}: ${call.args} argumentos, la native admite ${Math.max(...usable.map((e) => e.params))}`);
          }
        }
      }
    }
    console.log(`OK   ${checked} llamadas a natives comprobadas (existencia, lado y aridad)`);
  }

  for (const file of ['html/app.js', 'preview/sim.js', 'tools/build.js', 'tools/gen-sounds.js', 'tools/preview.js', 'tools/package.js']) {
    try { execFileSync(process.execPath, ['--check', path.join(root, file)]); console.log(`OK   sintaxis ${file}`); }
    catch (e) { fail(`sintaxis ${file}`); }
  }

  console.log(failures ? `\n${failures} fallo(s)` : '\nTodo correcto');
  process.exit(failures ? 1 : 0);
})();
