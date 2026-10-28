// vortexlabs_carhud · VortexLabs — núcleo de la NUI: comunicación, utilidades y color.
const FC = (window.FC = window.FC || {});

FC.version = '1.0.0';
FC.inGame = typeof window.GetParentResourceName === 'function';
FC.resource = FC.inGame ? window.GetParentResourceName() : 'vortexlabs_carhud';

// Fuera de FiveM (vista previa) las llamadas se entregan a FC.onPost o a la página contenedora.
FC.post = (name, data) => {
  if (!FC.inGame) {
    if (typeof FC.onPost === 'function') FC.onPost(name, data || {});
    else if (window.parent !== window) window.parent.postMessage({ fcPost: name, data: data || {} }, '*');
    return Promise.resolve(null);
  }
  return fetch(`https://${FC.resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json()).catch(() => null);
};

FC.clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
FC.isNum = (v) => typeof v === 'number' && Number.isFinite(v);

// Aproximación exponencial independiente de la tasa de refresco.
FC.approach = (current, target, dt, tau) => {
  if (tau <= 0) return target;
  return current + (target - current) * (1 - Math.exp(-dt / tau));
};

FC.KMH = 3.6;
FC.MPH = 2.236936;
FC.FEET = 3.28084;

FC.hexToRgb = (hex) => {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};
FC.rgbToCss = (c) => `rgb(${c[0]},${c[1]},${c[2]})`;
FC.mixRgb = (a, b, t) => [
  Math.round(a[0] + (b[0] - a[0]) * t),
  Math.round(a[1] + (b[1] - a[1]) * t),
  Math.round(a[2] + (b[2] - a[2]) * t),
];

FC.DEFAULT_ACCENT = '#FE3555'; // coral VortexLabs

// Segmento apagado: gris neutro, legible sobre fondos claros y oscuros.
FC.TRACK = FC.hexToRgb('#4a4a50');
const GREY = FC.hexToRgb('#b4b4be');
const LIGHT = FC.hexToRgb('#f5f5f7');

// Arco y acelerador (identidad VortexLabs): en rango normal, neutros (gris → blanco);
// solo el último quinto de la escala pasa al acento. Así el coral significa «atención».
FC.paletteFor = (accentHex) => {
  const accent = FC.hexToRgb(accentHex) || FC.hexToRgb(FC.DEFAULT_ACCENT);
  return [GREY, LIGHT, LIGHT, LIGHT, LIGHT, accent];
};

FC.intensity = (palette, t) => {
  const pos = FC.clamp(t, 0, 1) * (palette.length - 1);
  const lower = Math.min(palette.length - 2, Math.floor(pos));
  return FC.mixRgb(palette[lower], palette[lower + 1], pos - lower);
};

// Estado del motor: color continuo según la salud restante (0–100 %), desde daños
// leves. Sano = neutro (no pide atención); el daño calienta el color hasta el coral.
FC.ENGINE_STOPS = [
  [15, FC.hexToRgb('#fe3555')], // 15 % o menos: coral (avería)
  [35, FC.hexToRgb('#ff9442')], // naranja
  [55, FC.hexToRgb('#ffd34d')], // amarillo
  [75, FC.hexToRgb('#e6dd9a')], // amarillo pálido
  [90, FC.hexToRgb('#ecebe4')], // casi blanco
  [100, FC.hexToRgb('#f5f5f7')], // blanco neutro
];
FC.engineColor = (pct) => {
  const stops = FC.ENGINE_STOPS;
  const p = FC.clamp(pct, 0, 100);
  if (p <= stops[0][0]) return stops[0][1];
  for (let i = 1; i < stops.length; i += 1) {
    const [hi, cHi] = stops[i];
    const [lo, cLo] = stops[i - 1];
    if (p <= hi) return FC.mixRgb(cLo, cHi, (p - lo) / (hi - lo));
  }
  return stops[stops.length - 1][1];
};

FC.applyAccent = (hex) => {
  const rgb = FC.hexToRgb(hex) || FC.hexToRgb(FC.DEFAULT_ACCENT);
  const style = document.documentElement.style;
  style.setProperty('--fc-accent', FC.rgbToCss(rgb));
  style.setProperty('--fc-accent-soft', `rgba(${rgb[0]},${rgb[1]},${rgb[2]},0.7)`);
  style.setProperty('--fc-accent-glow', `rgba(${rgb[0]},${rgb[1]},${rgb[2]},0.38)`);
  return FC.paletteFor(hex);
};

// Escribe texto solo si cambia (evita invalidar el layout sin necesidad).
FC.setText = (el, text) => {
  if (el && el.__t !== text) {
    el.__t = text;
    el.textContent = text;
  }
};
FC.setAttr = (el, name, value) => {
  const v = String(value);
  if (el && el.getAttribute(name) !== v) el.setAttribute(name, v);
};

FC.formatInt = (n) => {
  const s = String(Math.abs(Math.round(n)));
  const grouped = s.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return (n < 0 && Math.round(n) !== 0 ? '-' : '') + grouped;
};
