// Genera los sonidos del cinturón (síntesis propia, sin muestras de terceros).
// Uso: node tools/gen-sounds.js  → html/sounds/*.wav (PCM 16 bits, mono, 44,1 kHz)
const fs = require('fs');
const path = require('path');

const RATE = 44100;
const out = path.resolve(__dirname, '..', 'html', 'sounds');

// Ruido determinista para que la salida sea reproducible.
let seed = 1337;
const noise = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return (seed / 0x3fffffff) - 1;
};

const buffer = (seconds) => new Float32Array(Math.ceil(seconds * RATE));

// Chasquido metálico: ráfaga de ruido filtrada + parciales inarmónicos que decaen rápido.
function click(buf, at, { gain = 1, tone = 2600, decay = 0.012, body = 0.035 }) {
  const start = Math.floor(at * RATE);
  const partials = [1, 1.47, 2.13, 2.91];
  let lp = 0;
  for (let i = 0; i < RATE * 0.12 && start + i < buf.length; i += 1) {
    const t = i / RATE;
    lp += (noise() - lp) * 0.35;
    const transient = lp * Math.exp(-t / 0.004) * 0.9;
    let ring = 0;
    partials.forEach((p, k) => {
      ring += Math.sin(2 * Math.PI * tone * p * t) * Math.exp(-t / (decay / (k + 1))) / (k + 1.5);
    });
    const thump = Math.sin(2 * Math.PI * 180 * t) * Math.exp(-t / body) * 0.35;
    buf[start + i] += gain * (transient + ring * 0.55 + thump);
  }
}

// Deslizamiento de la cincha: ruido paso banda con envolvente suave.
function slide(buf, at, length, gain) {
  const start = Math.floor(at * RATE);
  let a = 0;
  let b = 0;
  for (let i = 0; i < length * RATE && start + i < buf.length; i += 1) {
    const t = i / length / RATE;
    a += (noise() - a) * 0.25;
    b += (a - b) * 0.08;
    const env = Math.sin(Math.PI * t) ** 1.5;
    buf[start + i] += (a - b) * env * gain;
  }
}

// Campanilla de aviso: dos tonos suaves con ataque corto.
function chime(buf, at, freq, gain) {
  const start = Math.floor(at * RATE);
  for (let i = 0; i < RATE * 0.5 && start + i < buf.length; i += 1) {
    const t = i / RATE;
    const env = Math.min(1, t / 0.006) * Math.exp(-t / 0.16);
    const s = Math.sin(2 * Math.PI * freq * t) + 0.28 * Math.sin(2 * Math.PI * freq * 2 * t) + 0.08 * Math.sin(2 * Math.PI * freq * 3.01 * t);
    buf[start + i] += s * env * gain;
  }
}

function writeWav(name, data) {
  let peak = 0;
  data.forEach((v) => (peak = Math.max(peak, Math.abs(v))));
  const norm = peak > 0 ? 0.85 / peak : 1;
  const fadeOut = Math.floor(RATE * 0.01);
  const pcm = Buffer.alloc(data.length * 2);
  for (let i = 0; i < data.length; i += 1) {
    const fade = i > data.length - fadeOut ? (data.length - i) / fadeOut : 1;
    const v = Math.max(-1, Math.min(1, data[i] * norm * fade));
    pcm.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcm.length, 40);
  fs.writeFileSync(path.join(out, `${name}.wav`), Buffer.concat([header, pcm]));
  console.log(`${name}.wav  ${(44 + pcm.length) / 1024 | 0} KB`);
}

fs.mkdirSync(out, { recursive: true });

const on = buffer(0.32);
slide(on, 0, 0.11, 0.35);
click(on, 0.1, { gain: 0.8, tone: 2300 });
click(on, 0.132, { gain: 1, tone: 3100, decay: 0.018 });
writeWav('belt_on', on);

const off = buffer(0.38);
click(off, 0.0, { gain: 0.9, tone: 2700, decay: 0.014 });
slide(off, 0.04, 0.26, 0.42);
writeWav('belt_off', off);

const warn = buffer(0.62);
chime(warn, 0, 1046.5, 0.55);
chime(warn, 0.16, 1318.5, 0.5);
writeWav('belt_warn', warn);
