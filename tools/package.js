// Genera dist/vortexlabs_carhud-v<versión>.zip listo para instalar: compila la interfaz
// y copia solo lo que necesita el servidor (sin fuentes web, vista previa,
// herramientas, pruebas ni datos de nuestro servidor).
// Uso: node tools/package.js
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const root = path.resolve(__dirname, '..');
const manifest = fs.readFileSync(path.join(root, 'fxmanifest.lua'), 'utf8');
const version = (manifest.match(/^version\s+'([^']+)'/m) || [])[1] || '0.0.0';

execFileSync(process.execPath, [path.join(__dirname, 'build.js')], { stdio: 'inherit' });

const INCLUDE = [
  'fxmanifest.lua', 'config.lua', 'README.md', 'README.es.md', 'CHANGELOG.md', 'THIRD_PARTY.md',
  'shared', 'locales', 'bridge', 'client', 'server', 'data', 'html',
];
const SKIP = new Set(['node_modules', '.cache', 'dist', 'package-lock.json']);

const stage = fs.mkdtempSync(path.join(os.tmpdir(), 'vortexlabs_carhud-'));
const target = path.join(stage, 'vortexlabs_carhud');
fs.mkdirSync(target, { recursive: true });

function copy(src, dst) {
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dst, { recursive: true });
    for (const name of fs.readdirSync(src)) if (!SKIP.has(name)) copy(path.join(src, name), path.join(dst, name));
  } else {
    fs.copyFileSync(src, dst);
  }
}
INCLUDE.forEach((item) => copy(path.join(root, item), path.join(target, item)));
// La distribución empieza sin nitro guardado.
fs.writeFileSync(path.join(target, 'data', 'nitro.json'), '{}\n');
fs.writeFileSync(path.join(target, 'data', 'admin.json'), '{}\n'); // sin cambios de administración

const dist = path.join(root, 'dist');
fs.mkdirSync(dist, { recursive: true });
const zip = path.join(dist, `vortexlabs_carhud-v${version}.zip`);
if (fs.existsSync(zip)) fs.unlinkSync(zip);

// bsdtar (incluido en Windows 10+ y macOS) crea zip con -a; en Linux se usa zip.
const windowsTar = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe');
if (process.platform === 'win32' && fs.existsSync(windowsTar)) {
  execFileSync(windowsTar, ['-a', '-c', '-f', zip, '-C', stage, 'vortexlabs_carhud']);
} else if (process.platform === 'darwin') {
  execFileSync('tar', ['-a', '-c', '-f', zip, '-C', stage, 'vortexlabs_carhud']);
} else {
  execFileSync('zip', ['-qr', zip, 'vortexlabs_carhud'], { cwd: stage });
}
fs.rmSync(stage, { recursive: true, force: true });
console.log(`${path.relative(root, zip)}  ${(fs.statSync(zip).size / 1024).toFixed(0)} KB`);
