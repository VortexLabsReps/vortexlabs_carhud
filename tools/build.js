// Compila las fuentes de la interfaz (web/) en la versión que carga FiveM (html/).
// Uso: node tools/build.js        (sin dependencias)
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const web = path.join(root, 'web');
const out = path.join(root, 'html');

const read = (file) => fs.readFileSync(file, 'utf8');
const list = (dir, ext) => fs.readdirSync(dir).filter((f) => f.endsWith(ext)).sort().map((f) => path.join(dir, f));

const banner = '/* vortexlabs_carhud · VortexLabs — archivo generado por tools/build.js; edita web/ */\n';

const js = list(path.join(web, 'src'), '.js')
  .map((file) => `// ── ${path.basename(file)}\n${read(file).trim()}\n`)
  .join('\n');
fs.writeFileSync(path.join(out, 'app.js'), `${banner}(() => {\n'use strict';\n${js}})();\n`);

const css = list(path.join(web, 'styles'), '.css').map((file) => read(file).trim()).join('\n\n');
fs.writeFileSync(path.join(out, 'app.css'), `${banner}${css}\n`);

fs.copyFileSync(path.join(web, 'index.html'), path.join(out, 'index.html'));

console.log('html/app.js, html/app.css, html/index.html actualizados');
