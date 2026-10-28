/* vortexlabs_carhud · VortexLabs — archivo generado por tools/build.js; edita web/ */
(() => {
'use strict';
// ── 00-core.js
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

// ── 10-i18n.js
// Textos de la interfaz. La única fuente es locales/<idioma>.json (sección "ui"):
// Lua los envía en el mensaje 'init' junto con el inglés como respaldo.
FC.i18n = { strings: {}, fallback: {} };
FC.lang = 'en';

FC.setLocale = (lang, strings, fallback) => {
  FC.lang = typeof lang === 'string' ? lang : 'en';
  FC.i18n.strings = strings && typeof strings === 'object' ? strings : {};
  FC.i18n.fallback = fallback && typeof fallback === 'object' ? fallback : {};
};

FC.t = (key, vars) => {
  const { strings, fallback } = FC.i18n;
  let text = strings[key] != null ? strings[key] : fallback[key] != null ? fallback[key] : key;
  if (vars) text = text.replace(/\{(\w+)\}/g, (_, k) => (vars[k] != null ? vars[k] : ''));
  return text;
};

FC.applyI18n = (root) => {
  root.querySelectorAll('[data-i18n]').forEach((el) => FC.setText(el, FC.t(el.dataset.i18n)));
  root.querySelectorAll('[data-i18n-label]').forEach((el) => {
    el.setAttribute('aria-label', FC.t(el.dataset.i18nLabel));
    el.setAttribute('title', FC.t(el.dataset.i18nLabel));
  });
  document.documentElement.lang = FC.lang;
};

// ── 20-icons.js
// Iconos empaquetados en línea (sin CDN). Combustible, motor, nitro,
// crucero y flechas derivan de Lucide (licencia ISC, ver THIRD_PARTY.md).
// Cinturón y faro son pictogramas propios basados en la referencia aprobada.
const stroke = (body, extra) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"${extra || ''}>${body}</svg>`;

FC.icons = {
  fuel: stroke('<line x1="3" x2="15" y1="22" y2="22"/><line x1="4" x2="14" y1="9" y2="9"/><path d="M14 22V4a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v18"/><path d="M14 13h2a2 2 0 0 1 2 2v2a2 2 0 0 0 2 2a2 2 0 0 0 2-2V9.83a2 2 0 0 0-.59-1.42L18 5"/>'),
  engine: stroke('<path d="M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z"/><path d="M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"/><path d="M12 2v2"/><path d="M12 22v-2"/><path d="m17 20.66-1-1.73"/><path d="M11 10.27 7 3.34"/><path d="m20.66 17-1.73-1"/><path d="m3.34 7 1.73 1"/><path d="M14 12h8"/><path d="M2 12h2"/><path d="m20.66 7-1.73 1"/><path d="m3.34 17 1.73-1"/><path d="m17 3.34-1 1.73"/><path d="m11 13.73-4 6.93"/>'),
  nitro: stroke('<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>'),
  cruise: stroke('<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>'),
  left: stroke('<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>', ' stroke-width="2"'),
  right: stroke('<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>', ' stroke-width="2"'),
  close: stroke('<path d="M18 6 6 18"/><path d="m6 6 12 12"/>', ' stroke-width="2"'),
  navigation: stroke('<polygon points="12 2 19 21 12 17 5 21 12 2"/>', ' stroke-width="1.8"'),
  chevron: '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M5 1.2 9 7.6H1Z" fill="currentColor"/></svg>',
  // Persona con cinturón: cabeza, torso, banda diagonal y banda abdominal.
  belt:
    '<svg viewBox="0 0 18 18" aria-hidden="true"><circle cx="9" cy="2.2" r="2.05" fill="currentColor"/>' +
    '<path d="M4.8 17.2V10.6a4.2 4.2 0 0 1 8.4 0v6.6Z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>' +
    '<path d="M3.3 15.6 14.9 5.9" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>' +
    '<path d="M3.2 14.3h11.6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
  // Faro: haces inclinados (cortas), horizontales (largas) o tachado (apagadas).
  headlamp:
    '<svg viewBox="0 0 18 18" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' +
    '<path d="M10.2 3.2h1.9a4.9 5.8 0 0 1 0 11.6h-1.9Z"/>' +
    '<g class="fc-beam-low"><path d="M7.6 4.4 1.4 6.9"/><path d="M7.6 8.6 1.4 11.1"/><path d="M7.6 12.8 1.4 15.3"/></g>' +
    '<g class="fc-beam-high"><path d="M7.6 4.6H1.2"/><path d="M7.6 9H1.2"/><path d="M7.6 13.4H1.2"/></g>' +
    '<g class="fc-lamp-off"><path d="M1.6 16.4 16.4 1.6"/></g></svg>',
};

FC.mountIcons = (root) => {
  root.querySelectorAll('[data-icon]').forEach((el) => {
    el.innerHTML = FC.icons[el.dataset.icon] || '';
  });
  root.querySelectorAll('[data-tt]').forEach((el) => {
    const key = el.dataset.tt;
    el.innerHTML = key === 'belt' ? FC.icons.belt : key === 'lights' ? FC.icons.headlamp : FC.icons[key] || '';
  });
  root.querySelectorAll('[data-turn]').forEach((el) => {
    el.innerHTML = FC.icons[el.dataset.turn] || '';
  });
  root.querySelectorAll('[data-vs-arrow]').forEach((el) => {
    el.innerHTML = FC.icons.chevron;
  });
  root.querySelectorAll('[data-action="close"].fc-icon-btn, [data-admin-action="cancel"].fc-icon-btn').forEach((el) => {
    el.innerHTML = FC.icons.close;
  });
};

// ── 30-cluster.js
// Velocímetro: arco segmentado, lectura, intermitentes laterales, acelerador,
// testigos de la fila inferior y altitud. Se construye una sola vez; cada
// fotograma solo toca los elementos que cambian.
const SVG_NS = 'http://www.w3.org/2000/svg';
const ARC = { segments: 38, cx: 110, cy: 108, outer: 94, start: 150, sweep: 240 };
const THROTTLE_SEGMENTS = 18;
const LEVELS = 24; // cuantización del segmento parcial: evita escrituras inútiles

// Arco segmentado (velocímetro y nitro comparten geometría): 38 segmentos que
// crecen hacia el final, con una base oscura estática que los perfila.
FC.buildDial = (group, base) => {
  const segs = [];
  for (let i = 0; i < ARC.segments; i += 1) {
    const f = i / (ARC.segments - 1);
    const angle = ((ARC.start + f * ARC.sweep) * Math.PI) / 180;
    const inner = ARC.outer - (4 + f * 13);
    const line = document.createElementNS(SVG_NS, 'line');
    line.setAttribute('x1', (ARC.cx + Math.cos(angle) * inner).toFixed(2));
    line.setAttribute('y1', (ARC.cy + Math.sin(angle) * inner).toFixed(2));
    line.setAttribute('x2', (ARC.cx + Math.cos(angle) * ARC.outer).toFixed(2));
    line.setAttribute('y2', (ARC.cy + Math.sin(angle) * ARC.outer).toFixed(2));
    const width = 3.0 + f * 1.3;
    line.setAttribute('stroke-width', width.toFixed(2));
    line.setAttribute('stroke', FC.rgbToCss(FC.TRACK));
    const shadow = line.cloneNode();
    shadow.removeAttribute('stroke');
    shadow.setAttribute('stroke-width', (width + 1.6).toFixed(2));
    base.appendChild(shadow);
    group.appendChild(line);
    segs.push({ el: line, f, level: 0 });
  }
  return segs;
};

// Enciende la fracción indicada; cada segmento lleva el color de su posición.
FC.paintSegments = (segs, fraction, palette, mode) => {
  const lit = fraction * segs.length;
  const full = Math.floor(lit);
  for (let i = 0; i < segs.length; i += 1) {
    const seg = segs[i];
    const level = i < full ? LEVELS : i === full ? Math.round((lit - full) * LEVELS) : 0;
    if (level === seg.level) continue;
    seg.level = level;
    const color = level === 0 ? FC.TRACK : FC.mixRgb(FC.TRACK, FC.intensity(palette, seg.f), level / LEVELS);
    if (mode === 'background') seg.el.style.backgroundColor = FC.rgbToCss(color);
    else seg.el.setAttribute('stroke', FC.rgbToCss(color));
  }
};

class Cluster {
  constructor(el) {
    this.el = el;
    this.q = (s) => el.querySelector(s);
    this.speedEl = this.q('[data-speed]');
    this.secondaryEl = this.q('[data-secondary]');
    this.unitEl = this.q('[data-unit]');
    this.gearEl = this.q('[data-gear]');
    this.gasEl = this.q('[data-gas]');
    this.gasLabelEl = this.q('[data-gas-label]');
    this.throttleEl = this.q('[data-throttle]');
    this.ttRow = this.q('[data-telltales]');
    this.altEl = this.q('[data-alt]');
    this.turns = { left: this.q('[data-turn="left"]'), right: this.q('[data-turn="right"]') };
    this.ind = 0;
    this.cruiseMark = this.q('[data-cruise-mark]');
    this.tt = {};
    el.querySelectorAll('[data-tt]').forEach((node) => (this.tt[node.dataset.tt] = node));
    this.altCells = [...el.querySelectorAll('[data-alt-cell]')].map((cell) => ({
      label: cell.querySelector('[data-alt-label]'),
      value: cell.querySelector('[data-alt-value]'),
      unit: cell.querySelector('[data-alt-unit]'),
    }));

    this.profile = { category: 'car', gear: true, rpm: true, throttle: true, scaleKmh: 260, redline: 8000 };
    this.unit = 'kmh';
    this.modules = {};
    this.palette = FC.paletteFor(FC.DEFAULT_ACCENT);

    // Valores mostrados (animados) y objetivos (última lectura).
    this.cur = { speed: 0, pedal: 0, rpm: 0 };
    this.tgt = { speed: 0, pedal: 0, rpm: 0 };
    this.gear = null;
    this.alt = { msl: null, agl: null, vs: null };

    this.buildArc();
    this.buildThrottle();
    this.renderSpeedNumber(0);
  }

  buildArc() {
    this.arcSegs = FC.buildDial(this.q('[data-segments]'), this.q('[data-segments-base]'));
  }

  buildThrottle() {
    this.gasSegs = [];
    for (let i = 0; i < THROTTLE_SEGMENTS; i += 1) {
      const f = i / (THROTTLE_SEGMENTS - 1);
      const bar = document.createElement('b');
      bar.style.height = `${(3 + f * 14).toFixed(2)}px`;
      this.throttleEl.appendChild(bar);
      this.gasSegs.push({ el: bar, f, level: 0 });
    }
  }

  setPalette(palette) {
    this.palette = palette;
    this.arcSegs.forEach((s) => (s.level = -1));
    this.gasSegs.forEach((s) => (s.level = -1));
    this.paint();
  }

  setProfile(profile) {
    this.profile = profile;
    const el = this.el;
    FC.setAttr(el, 'data-profile', profile.category);
    FC.setAttr(el, 'data-aircraft', !!profile.aircraft);
    FC.setAttr(el, 'data-has-gear', !!profile.gear);
    FC.setText(this.gasLabelEl, FC.t(profile.aircraft ? 'gauge.power' : 'gauge.gas'));
    this.gear = null;
    this.alt = { msl: null, agl: null, vs: null };
    this.applyVisibility();
    this.renderAltLabels();
    this.renderCruiseMark();
  }

  setModules(modules) {
    this.modules = modules || {};
    this.applyVisibility();
  }

  applyVisibility() {
    const p = this.profile;
    const m = this.modules;
    this.gasEl.hidden = !(p.throttle && m.throttle !== false);
    const tt = p.telltales || {};
    const showRow = !p.aircraft && m.telltales !== false && (tt.belt || tt.lights || tt.cruise);
    this.ttRow.hidden = !showRow;
    this.tt.belt.hidden = !tt.belt;
    this.tt.lights.hidden = !tt.lights;
    this.tt.cruise.hidden = !tt.cruise;
    const arrows = !p.aircraft && m.telltales !== false && !!tt.indicators;
    this.turns.left.hidden = !arrows;
    this.turns.right.hidden = !arrows;
    this.altEl.hidden = !(p.aircraft && m.altitude !== false);
    this.renderSecondary(true);
    if (this.onFooterChange) this.onFooterChange();
  }

  setUnit(unit) {
    this.unit = unit === 'mph' ? 'mph' : 'kmh';
    FC.setText(this.unitEl, this.unit === 'mph' ? 'MPH' : 'KM/H');
    this.renderSpeedNumber(this.cur.speed, true);
    this.renderAltLabels();
    this.renderAltValues(true);
    this.renderCruiseMark();
  }

  // Lecturas rápidas: s (m/s), r (0–1), g (marcha), p (pedal 0–1), aeronaves: m, a, v.
  setFast(d) {
    if (FC.isNum(d.s)) this.tgt.speed = Math.max(0, d.s);
    if (FC.isNum(d.r)) this.tgt.rpm = FC.clamp(d.r, 0, 1);
    if (FC.isNum(d.p)) this.tgt.pedal = FC.clamp(d.p, 0, 1);
    if (d.g !== undefined && d.g !== this.gear) {
      this.gear = d.g;
      FC.setText(this.gearEl, d.g === 0 ? 'R' : d.g == null ? '' : String(d.g));
    }
    if (this.profile.aircraft) {
      if (d.m !== undefined) this.alt.msl = d.m;
      if (d.a !== undefined) this.alt.agl = d.a;
      if (d.v !== undefined) this.alt.vs = d.v;
      this.renderAltValues();
    }
  }

  setTelltales(t) {
    if (!t) return;
    const tt = this.tt;
    if (t.belt !== undefined) {
      FC.setAttr(tt.belt, 'data-state', t.belt);
      tt.belt.setAttribute('aria-label', FC.t(t.belt === 'on' ? 'label.belt.on' : 'label.belt.off'));
    }
    if (t.lights !== undefined) {
      FC.setAttr(tt.lights, 'data-state', t.lights);
      tt.lights.setAttribute('aria-label', FC.t(`label.lights.${t.lights}`));
    }
    if (t.ind !== undefined && t.ind !== this.ind) this.setIndicators(t.ind);
    if (t.cruise !== undefined) {
      this.cruise = t.cruise; // m/s objetivo o 0
      FC.setAttr(tt.cruise, 'data-state', t.cruise > 0 ? 'on' : 'off');
      FC.setAttr(this.el, 'data-cruise', t.cruise > 0);
      this.renderCruiseMark();
    }
  }

  // Estado real del juego: 1 izquierda, 2 derecha, 3 emergencia. Al cambiar se
  // reinicia la animación de ambos a la vez para que parpadeen sincronizados.
  setIndicators(ind) {
    this.ind = ind;
    const states = { left: ind === 1 || ind === 3, right: ind === 2 || ind === 3 };
    Object.entries(this.turns).forEach(([side, el]) => {
      el.style.animation = 'none';
      FC.setAttr(el, 'data-state', states[side] ? 'on' : 'off');
      el.setAttribute('aria-label', FC.t(`label.${side}`));
    });
    void this.el.offsetWidth; // aplica el reinicio antes de reanudar
    Object.values(this.turns).forEach((el) => { el.style.animation = ''; });
  }

  footerLeftVisible() {
    return !this.ttRow.hidden || !this.altEl.hidden;
  }

  snap() {
    this.cur.speed = this.tgt.speed;
    this.cur.pedal = this.tgt.pedal;
    this.cur.rpm = this.tgt.rpm;
    this.paint();
  }

  // Devuelve true mientras quede movimiento por interpolar.
  step(dt) {
    const c = this.cur;
    const t = this.tgt;
    c.speed = FC.approach(c.speed, t.speed, dt, 0.055);
    c.pedal = FC.approach(c.pedal, t.pedal, dt, 0.04);
    c.rpm = FC.approach(c.rpm, t.rpm, dt, 0.05);
    let moving = false;
    if (Math.abs(c.speed - t.speed) < 0.01) c.speed = t.speed; else moving = true;
    if (Math.abs(c.pedal - t.pedal) < 0.002) c.pedal = t.pedal; else moving = true;
    if (Math.abs(c.rpm - t.rpm) < 0.002) c.rpm = t.rpm; else moving = true;
    this.paint();
    return moving;
  }

  paint() {
    const scaleMs = (this.profile.scaleKmh || 260) / FC.KMH;
    FC.paintSegments(this.arcSegs, FC.clamp(this.cur.speed / scaleMs, 0, 1), this.palette, 'stroke');
    if (!this.gasEl.hidden) FC.paintSegments(this.gasSegs, this.cur.pedal, this.palette, 'background');
    this.renderSpeedNumber(this.cur.speed);
    this.renderSecondary();
  }

  renderSpeedNumber(speedMs, force) {
    const factor = this.unit === 'mph' ? FC.MPH : FC.KMH;
    const value = Math.min(999, Math.round(speedMs * factor));
    if (value === this.shownSpeed && !force) return;
    this.shownSpeed = value;
    FC.setText(this.speedEl, String(value));
  }

  renderSecondary(force) {
    const p = this.profile;
    const el = this.secondaryEl;
    if (p.aircraft) {
      FC.setAttr(el, 'data-kind', 'tag');
      FC.setText(el, FC.t('gauge.groundSpeed'));
      return;
    }
    FC.setAttr(el, 'data-kind', 'rpm');
    if (!p.rpm || this.modules.rpm === false) {
      FC.setText(el, '');
      return;
    }
    const thousands = (this.cur.rpm * (p.redline || 8000)) / 1000;
    const text = `${thousands.toFixed(1)} ${FC.t('gauge.rpm')}`;
    if (force || el.__t !== text) FC.setText(el, text);
  }

  renderAltLabels() {
    const p = this.profile;
    if (!p.aircraft) return;
    const [a, b] = this.altCells;
    const length = this.unit === 'mph' ? 'ft' : 'm';
    if (p.aircraft === 'heli') {
      FC.setText(a.label, FC.t('alt.agl'));
      FC.setText(b.label, FC.t('alt.vs'));
      FC.setText(a.unit, length);
      FC.setText(b.unit, this.unit === 'mph' ? 'ft/min' : 'm/s');
    } else {
      FC.setText(a.label, FC.t('alt.msl'));
      FC.setText(b.label, FC.t('alt.agl'));
      FC.setText(a.unit, length);
      FC.setText(b.unit, length);
    }
  }

  renderAltValues() {
    const p = this.profile;
    if (!p.aircraft || this.altEl.hidden) return;
    const [a, b] = this.altCells;
    const imperial = this.unit === 'mph';
    const len = (m) => (FC.isNum(m) ? FC.formatInt(imperial ? m * FC.FEET : m) : '—');
    if (p.aircraft === 'heli') {
      FC.setText(a.value, len(this.alt.agl));
      const vs = this.alt.vs;
      let text = '—';
      let dir = 'level';
      if (FC.isNum(vs)) {
        const shown = imperial ? Math.round((vs * FC.FEET * 60) / 10) * 10 : Math.round(vs * 10) / 10;
        text = imperial ? FC.formatInt(Math.abs(shown)) : Math.abs(shown).toFixed(1);
        if (shown > 0) dir = 'up'; else if (shown < 0) dir = 'down';
      }
      FC.setText(b.value, text);
      FC.setAttr(this.altEl, 'data-vs', dir);
    } else {
      FC.setText(a.value, len(this.alt.msl));
      FC.setText(b.value, len(this.alt.agl));
      FC.setAttr(this.altEl, 'data-vs', 'none');
    }
  }

  renderCruiseMark() {
    const target = this.cruise || 0;
    if (!(target > 0)) return;
    const f = FC.clamp(target / ((this.profile.scaleKmh || 260) / FC.KMH), 0, 1);
    const angle = ((ARC.start + f * ARC.sweep) * Math.PI) / 180;
    const m = this.cruiseMark;
    m.setAttribute('x1', (ARC.cx + Math.cos(angle) * 98).toFixed(2));
    m.setAttribute('y1', (ARC.cy + Math.sin(angle) * 98).toFixed(2));
    m.setAttribute('x2', (ARC.cx + Math.cos(angle) * 104).toFixed(2));
    m.setAttribute('y2', (ARC.cy + Math.sin(angle) * 104).toFixed(2));
  }
}

FC.Cluster = Cluster;

// ── 40-status.js
// Estado del vehículo: combustible y motor (fila inferior), anillo de nitro y avisos.
// Valores: número = dato real · null = aún sin dato · false = no aplicable (se oculta).
class Status {
  constructor(root) {
    this.root = root;
    this.noticeEl = root.querySelector('[data-notice]');
    this.mods = {};
    root.querySelectorAll('[data-mod]').forEach((node) => {
      const name = node.dataset.mod;
      this.mods[name] = { el: node, icon: node.querySelector('.fc-mini-icon'), bar: node.querySelector('[data-bar]'), value: node.querySelector('[data-value]'), cur: 0, tgt: 0, shown: -2 };
      node.setAttribute('aria-label', FC.t(`label.${name}`));
    });
    // Anillo de nitro: misma geometría segmentada y escala de colores que el velocímetro.
    this.nitroEl = root.querySelector('[data-nitro-ring]');
    this.nitroValue = root.querySelector('[data-nitro-value]');
    this.nitroSegs = FC.buildDial(root.querySelector('[data-nitro-segments]'), root.querySelector('[data-nitro-base]'));
    this.nitro = { cur: 0, tgt: 0, shown: -2 };
    this.palette = FC.paletteFor(FC.DEFAULT_ACCENT);
    this.profile = {};
    this.modules = {};
    this.thresholds = { fuel: 15, engine: 35 };
    this.data = { fuel: null, eng: null, run: true, nos: null, beltWarn: false };
    this.transient = null;
    this.onLayoutChange = null;
  }

  setPalette(palette) {
    this.palette = palette;
    this.nitroSegs.forEach((s) => (s.level = -1));
    this.paintNitro();
  }

  setProfile(profile) {
    this.profile = profile;
    this.data = { fuel: null, eng: null, run: true, nos: null, beltWarn: false };
    Object.values(this.mods).forEach((m) => { m.cur = 0; m.tgt = 0; m.shown = -2; });
    this.nitro = { cur: 0, tgt: 0, shown: -2 };
    this.refreshVisibility(true);
    this.renderStates();
    this.renderNotice();
  }

  setModules(modules) {
    this.modules = modules || {};
    this.refreshVisibility();
    this.renderNotice();
  }

  minisVisible() {
    return !this.mods.fuel.el.hidden || !this.mods.engine.el.hidden;
  }

  refreshVisibility(force) {
    const p = this.profile;
    const m = this.modules;
    const d = this.data;
    const show = {
      fuel: !!p.fuel && m.fuel !== false && d.fuel !== false,
      engine: !!p.engine && m.engine !== false,
    };
    let changed = !!force;
    Object.keys(show).forEach((name) => {
      const el = this.mods[name].el;
      if (el.hidden === show[name]) {
        el.hidden = !show[name];
        changed = true;
      }
    });
    const nitro = !!p.nitro && m.nitro !== false && !!d.nos;
    if (this.nitroEl.hidden === nitro) {
      this.nitroEl.hidden = !nitro;
      FC.setAttr(this.root, 'data-nitro', nitro);
      changed = true;
    }
    if (changed && this.onLayoutChange) this.onLayoutChange();
  }

  // Datos lentos parciales: solo llegan los campos que han cambiado.
  setSlow(s) {
    const d = this.data;
    let visibility = false;
    if ('fuel' in s) {
      const fuel = s.fuel === -1 || s.fuel === null ? null : s.fuel; // -1: aún sin dato (0 es depósito vacío)
      if ((d.fuel === false) !== (fuel === false)) visibility = true;
      d.fuel = fuel;
    }
    if ('eng' in s) d.eng = s.eng;
    if ('run' in s) d.run = s.run;
    if ('nos' in s) {
      if (!!d.nos !== !!s.nos) visibility = true;
      d.nos = s.nos;
    }
    if ('beltWarn' in s) d.beltWarn = s.beltWarn;
    if (visibility) this.refreshVisibility();

    const mods = this.mods;
    mods.fuel.tgt = FC.isNum(d.fuel) ? FC.clamp(d.fuel / 100, 0, 1) : 0;
    mods.engine.tgt = FC.isNum(d.eng) ? FC.clamp(d.eng / 100, 0, 1) : 0;
    mods.fuel.known = FC.isNum(d.fuel);
    mods.engine.known = FC.isNum(d.eng);
    this.nitro.tgt = d.nos && d.nos.cap > 0 ? FC.clamp(d.nos.amt / d.nos.cap, 0, 1) : 0;
    this.renderStates();
    this.renderNotice();
  }

  renderStates() {
    const d = this.data;
    const th = this.thresholds;
    const fuel = this.mods.fuel.el;
    FC.setAttr(fuel, 'data-nodata', d.fuel === null);
    FC.setAttr(fuel, 'data-warn', FC.isNum(d.fuel) && d.fuel <= th.fuel);
    const engine = this.mods.engine.el;
    FC.setAttr(engine, 'data-nodata', d.eng === null);
    // Sin data-warn: el color del motor es la graduación continua (paintEngine); el aviso
    // «Motor dañado» va aparte, con su propio umbral (thresholds.engine).
    FC.setAttr(engine, 'data-running', d.run !== false);
    // Nitro: el aro es solo la carga restante; el rayo se ilumina en uso.
    const state = !d.nos ? 'none' : d.nos.on ? 'active' : d.nos.amt <= 0 ? 'empty' : 'idle';
    FC.setAttr(this.nitroEl, 'data-state', state);
    if (d.nos) {
      const color = FC.intensity(this.palette, this.nitro.tgt);
      this.nitroEl.style.setProperty('--fc-nitro-color', FC.rgbToCss(color));
      this.nitroEl.style.setProperty('--fc-nitro-glow', `rgba(${color[0]},${color[1]},${color[2]},0.42)`);
      this.nitroEl.setAttribute('aria-label', FC.t('label.nitro'));
      this.nitroEl.setAttribute('aria-valuenow', String(Math.round(this.nitro.tgt * 100)));
    }
  }

  warnings() {
    if (this.modules.notices === false) return [];
    const d = this.data;
    const th = this.thresholds;
    const list = [];
    if (FC.isNum(d.fuel) && this.profile.fuel) {
      if (d.fuel <= 0.5) list.push(['notice.fuelEmpty', 'danger']);
      else if (d.fuel <= th.fuel) list.push(['notice.fuelLow', 'warn']);
    }
    if (FC.isNum(d.eng) && this.profile.engine) {
      if (d.eng <= 0) list.push(['notice.engineDead', 'danger']);
      else if (d.eng <= th.engine) list.push(['notice.engineDamaged', 'warn']);
    }
    if (d.beltWarn) list.push(['notice.belt', 'danger']);
    return list;
  }

  // Aviso transitorio (crucero, llaves, cinturón al salir…). Tiene prioridad sobre los persistentes.
  flash(text, kind, ms) {
    clearTimeout(this.transientTimer);
    this.transient = { text, kind: kind || 'info' };
    this.renderNotice();
    this.transientTimer = setTimeout(() => {
      this.transient = null;
      this.renderNotice();
    }, ms || 2200);
  }

  renderNotice() {
    const el = this.noticeEl;
    let text = '';
    let kind = 'warn';
    if (this.transient) {
      text = this.transient.text;
      kind = this.transient.kind;
    } else {
      const list = this.warnings();
      if (list.length) {
        text = list.map(([key]) => FC.t(key)).join(' · ');
        kind = list.some(([, k]) => k === 'danger') ? 'danger' : 'warn';
      }
    }
    if (!text) {
      if (!el.hidden) el.hidden = true;
      el.__t = '';
      return;
    }
    FC.setAttr(el, 'data-kind', kind);
    FC.setText(el, text);
    if (el.hidden) el.hidden = false;
  }

  // Color del icono y de la barra del motor a partir de la salud mostrada (animada).
  paintEngine(m) {
    if (!m.known) {
      m.icon.style.color = '';
      m.bar.style.backgroundColor = '';
      m.color = '';
      return;
    }
    const css = FC.rgbToCss(FC.engineColor(m.cur * 100));
    if (css === m.color) return;
    m.color = css;
    m.icon.style.color = css;
    m.bar.style.backgroundColor = css;
  }

  paintNitro() {
    if (this.nitroEl.hidden) return;
    FC.paintSegments(this.nitroSegs, this.nitro.cur, this.palette, 'stroke');
  }

  step(dt) {
    let moving = false;
    Object.entries(this.mods).forEach(([name, m]) => {
      if (m.el.hidden) { m.cur = m.tgt; return; }
      // El motor transita más despacio: el color y la barra recorren la escala al dañar o reparar.
      m.cur = FC.approach(m.cur, m.tgt, dt, name === 'engine' ? 0.45 : 0.12);
      if (Math.abs(m.cur - m.tgt) < 0.003) m.cur = m.tgt; else moving = true;
      const q = Math.round(m.cur * 1000);
      if (q !== m.barQ) {
        m.barQ = q;
        m.bar.style.transform = `scaleX(${(q / 1000).toFixed(3)})`;
        if (name === 'engine') this.paintEngine(m);
      }
      const pct = m.known ? Math.round(m.tgt * 100) : -1;
      if (pct !== m.shown) {
        m.shown = pct;
        m.value.innerHTML = pct < 0 ? '—' : `${pct}<small>%</small>`;
      }
    });
    const n = this.nitro;
    if (this.nitroEl.hidden) {
      n.cur = n.tgt;
    } else {
      n.cur = FC.approach(n.cur, n.tgt, dt, 0.1);
      if (Math.abs(n.cur - n.tgt) < 0.002) n.cur = n.tgt; else moving = true;
      this.paintNitro();
      const pct = Math.round(n.tgt * 100);
      if (pct !== n.shown) {
        n.shown = pct;
        FC.setText(this.nitroValue, `${pct}%`);
      }
    }
    return moving;
  }
}

FC.Status = Status;

// ── 50-layout.js
// Posición y escala del conjunto. Escala base proporcional a la altura (1080p = 1),
// así 1440p, 4K y ultrawide conservan el mismo tamaño aparente. Siempre dentro
// de la zona segura del juego y sin solapar el minimapa.
// La posición guardada es la esquina inferior derecha (fracción de pantalla): al
// aparecer u ocultarse el nitro, el velocímetro no se desplaza.
// Tamaño base del conjunto a 1080p (1,01), ajustado y aprobado.
const BASE_SCALE = { cluster: 1.01 };
const NOTICE_SPACE = 40; // espacio reservado encima para los avisos
const COMPACT_SCALE = 0.92;

class Layout {
  constructor(root, boxes, onMove) {
    this.root = root;
    this.boxes = boxes;
    this.onMove = onMove;
    this.settings = { cluster: { scale: 1 } };
    this.safe = 1;
    this.minimap = null;
    this.compact = false;
    this.pos = {};
    this.editing = false;
    window.addEventListener('resize', () => this.apply());
    Object.entries(boxes).forEach(([name, el]) => this.bindDrag(name, el));
  }

  ui() {
    return FC.clamp(window.innerHeight / 1080, 0.5, 3);
  }

  scaleOf(name) {
    let s = this.ui() * BASE_SCALE[name] * ((this.settings[name] && this.settings[name].scale) || 1);
    if (name === 'cluster' && this.compact) s *= COMPACT_SCALE;
    return s;
  }

  bounds() {
    const W = window.innerWidth;
    const H = window.innerHeight;
    const ui = this.ui();
    const inset = (1 - FC.clamp(this.safe, 0.85, 1)) / 2;
    return { W, H, px: Math.max(W * inset, 22 * ui), py: Math.max(H * inset, 22 * ui), gap: 10 * ui };
  }

  setSettings(settings) {
    this.settings = { cluster: { ...settings.cluster }, location: { ...(settings.location || {}) } };
    this.apply();
  }

  setSafeZone(safe, minimap, gap) {
    this.safe = FC.isNum(safe) ? safe : 1;
    if (FC.isNum(gap)) this.gap = gap;
    this.minimap = minimap || null;
    this.apply();
  }

  apply() {
    document.documentElement.style.setProperty('--fc-ui', this.ui().toFixed(4));
    this.placeLocation();
    if (this.root.dataset.visible !== 'true') return;
    Object.keys(this.boxes).forEach((name) => this.place(name));
  }

  // Tamaño sin transformar con decimales (offsetWidth redondea y, escalado, se desvía píxeles).
  // Si a la escala elegida no cabe (pantallas pequeñas o zona segura estrecha), se
  // reduce lo justo para que nunca quede recortado; la preferencia guardada no cambia.
  measure(name) {
    const el = this.boxes[name];
    const cs = getComputedStyle(el);
    const w0 = parseFloat(cs.width) || 0;
    const h0 = parseFloat(cs.height) || 0;
    const b = this.bounds();
    let s = this.scaleOf(name);
    if (w0 && h0) {
      const fit = Math.min((b.H - 2 * b.py) / (h0 + NOTICE_SPACE), (b.W - 2 * b.px) / w0);
      if (s > fit) s = fit;
    }
    return { el, s, w: w0 * s, h: h0 * s };
  }

  limits(name, m) {
    const b = this.bounds();
    const top = b.py + NOTICE_SPACE * m.s;
    const edge = 0.25; // margen subpíxel frente al redondeo del translate
    return { ...b, minX: b.px + edge, maxX: Math.max(b.px, b.W - b.px - m.w - edge), minY: top + edge, maxY: Math.max(top, b.H - b.py - m.h - edge) };
  }

  place(name) {
    const m = this.measure(name);
    if (!m.w || !m.h) return;
    const L = this.limits(name, m);
    const cfg = this.settings[name] || {};
    let x;
    let y;
    if (FC.isNum(cfg.x) && FC.isNum(cfg.y)) {
      x = cfg.x * L.W - m.w;
      y = cfg.y * L.H - m.h;
    } else {
      x = L.W - L.px - m.w;
      y = L.H - L.py - m.h;
    }
    x = FC.clamp(x, L.minX, L.maxX);
    y = FC.clamp(y, L.minY, L.maxY);
    [x, y] = this.avoidMinimap(x, y, m, L);
    this.setPos(name, m, x, y);
  }

  avoidMinimap(x, y, m, L) {
    const mm = this.minimap;
    if (!mm) return [x, y];
    const r = { l: mm.l * L.W - L.gap, t: mm.t * L.H - L.gap, r: mm.r * L.W + L.gap, b: mm.b * L.H + L.gap };
    const overlaps = x < r.r && x + m.w > r.l && y < r.b && y + m.h > r.t;
    if (!overlaps) return [x, y];
    if (r.r <= L.maxX) return [Math.max(x, r.r), y];
    if (r.t - m.h >= L.minY) return [x, r.t - m.h];
    return [x, y];
  }

  setPos(name, m, x, y) {
    this.pos[name] = { x, y, w: m.w, h: m.h };
    m.el.style.transform = `translate(${x.toFixed(2)}px, ${y.toFixed(2)}px) scale(${m.s.toFixed(4)})`;
    // Opacidad elegida por el jugador (variable CSS; el fundido del HUD va en su capa).
    const opacity = (this.settings[name] && this.settings[name].opacity) || 1;
    const value = opacity >= 1 ? '' : opacity.toFixed(2);
    if (m.el.style.getPropertyValue('--fc-opacity') !== value) m.el.style.setProperty('--fc-opacity', value);
  }

  // ── Ubicación: encima del minimapa, con su mismo ancho exterior y bordes alineados ──
  setLocationEl(el) {
    this.locEl = el;
    this.bindLocationDrag(el);
  }

  // Rectángulo del minimapa en píxeles (lo envía Lua; si aún no llegó, la misma fórmula).
  minimapRect() {
    const W = window.innerWidth;
    const H = window.innerHeight;
    let mm = this.minimap;
    if (!mm) {
      // Mismas medidas que usa Lua (frontend.xml, alineado L/B dentro de la zona segura).
      const inset = (1 - FC.clamp(this.safe, 0.85, 1)) / 2;
      const scaleX = (16 / 9) / (W / H);
      mm = { l: Math.max(0, inset - 0.0045), r: inset - 0.0045 + 0.15 * scaleX, t: 1 - inset + 0.002 - 0.188888, b: 1 - inset + 0.002 };
    }
    return { l: mm.l * W, r: mm.r * W, t: mm.t * H, b: mm.b * H };
  }

  locationGeometry() {
    const el = this.locEl;
    const cfg = this.settings.location || {};
    const W = window.innerWidth;
    const H = window.innerHeight;
    const s = this.ui() * (cfg.scale || 1);
    const mm = this.minimapRect();
    // Ancho exterior = ancho visible del minimapa (la escala del jugador solo cambia
    // el alto y el texto). Los nombres largos se recortan dentro de ese ancho.
    const w = mm.r - mm.l;
    const cssWidth = `${(w / s).toFixed(3)}px`;
    if (el.style.width !== cssWidth) el.style.width = cssWidth;
    const h = (parseFloat(getComputedStyle(el).height) || 0) * s;
    // Límites: la zona segura, salvo por la izquierda, donde GTA dibuja el minimapa
    // un poco por fuera de ella (posX −0,0045): así la etiqueta sigue alineada con él.
    const inset = (1 - FC.clamp(this.safe, 0.85, 1)) / 2;
    const px = W * inset;
    const py = H * inset;
    const minX = Math.max(0, Math.min(px, mm.l));
    // Ancla: bordes izquierdo y derecho del minimapa, con la separación configurada
    // sobre su borde superior (12 px a 1080p, proporcional a la resolución).
    const anchor = { x: mm.l, y: mm.t - (FC.isNum(this.gap) ? this.gap : 12) * this.ui() };
    return { s, w, h, W, H, anchor, minX, maxX: Math.max(minX, W - px - w), minY: py, maxY: Math.max(py, H - py - h) };
  }

  placeLocation() {
    if (!this.locEl) return;
    const g = this.locationGeometry();
    const cfg = this.settings.location || {};
    // Sin posición guardada: la predeterminada del servidor (Config.Location.default).
    const def = this.locDefault || { x: 0, y: 0 };
    const saved = FC.isNum(cfg.x) && FC.isNum(cfg.y);
    const x = FC.clamp(g.anchor.x + (saved ? cfg.x : def.x) * g.H, g.minX, g.maxX);
    const y = FC.clamp(g.anchor.y + (saved ? cfg.y : def.y) * g.H - g.h, g.minY, g.maxY);
    this.setLocationPos(g, x, y);
  }

  setLocationPos(g, x, y) {
    this.locPos = { x, y, w: g.w, h: g.h, anchor: g.anchor, H: g.H };
    this.locEl.style.transform = `translate(${x.toFixed(2)}px, ${y.toFixed(2)}px) scale(${g.s.toFixed(4)})`;
  }

  // Al soltar se guarda el desplazamiento respecto al minimapa (en altos de pantalla):
  // así sigue anclada al minimapa al cambiar la resolución o la zona segura.
  bindLocationDrag(el) {
    let drag = null;
    el.addEventListener('pointerdown', (e) => {
      if (!this.editing || e.button !== 0 || !this.locPos) return;
      e.preventDefault();
      el.setPointerCapture(e.pointerId);
      drag = { id: e.pointerId, sx: e.clientX, sy: e.clientY, x: this.locPos.x, y: this.locPos.y };
      el.classList.add('is-dragging');
    });
    el.addEventListener('pointermove', (e) => {
      if (!drag || e.pointerId !== drag.id) return;
      const g = this.locationGeometry();
      this.setLocationPos(g, FC.clamp(drag.x + e.clientX - drag.sx, g.minX, g.maxX), FC.clamp(drag.y + e.clientY - drag.sy, g.minY, g.maxY));
    });
    const end = (e) => {
      if (!drag || e.pointerId !== drag.id) return;
      drag = null;
      el.classList.remove('is-dragging');
      const p = this.locPos;
      const point = { x: (p.x - p.anchor.x) / p.H, y: (p.y + p.h - p.anchor.y) / p.H };
      this.settings.location = { ...this.settings.location, ...point };
      this.placeLocation();
      if (this.onMove) this.onMove('location', point);
    };
    el.addEventListener('pointerup', end);
    el.addEventListener('pointercancel', end);
  }

  setEditing(on) {
    this.editing = !!on;
    this.root.dataset.editing = String(this.editing);
  }

  bindDrag(name, el) {
    let drag = null;
    el.addEventListener('pointerdown', (e) => {
      if (!this.editing || e.button !== 0) return;
      e.preventDefault();
      el.setPointerCapture(e.pointerId);
      const p = this.pos[name] || { x: 0, y: 0 };
      drag = { id: e.pointerId, sx: e.clientX, sy: e.clientY, x: p.x, y: p.y };
      el.classList.add('is-dragging');
    });
    el.addEventListener('pointermove', (e) => {
      if (!drag || e.pointerId !== drag.id) return;
      const m = this.measure(name);
      const L = this.limits(name, m);
      const x = FC.clamp(drag.x + e.clientX - drag.sx, L.minX, L.maxX);
      const y = FC.clamp(drag.y + e.clientY - drag.sy, L.minY, L.maxY);
      this.setPos(name, m, x, y);
    });
    const end = (e) => {
      if (!drag || e.pointerId !== drag.id) return;
      drag = null;
      el.classList.remove('is-dragging');
      const p = this.pos[name];
      const b = this.bounds();
      const point = { x: (p.x + p.w) / b.W, y: (p.y + p.h) / b.H };
      this.settings[name] = { ...this.settings[name], ...point };
      this.place(name);
      if (this.onMove) this.onMove(name, point);
    };
    el.addEventListener('pointerup', end);
    el.addEventListener('pointercancel', end);
  }
}

FC.Layout = Layout;

// ── 60-settings.js
// Menú de ajustes. Aplica los cambios en vivo; Lua valida y guarda cada cambio.
const SWATCHES = ['#FE3555', '#F5F5F7', '#41E7A3', '#4DA3FF', '#9B8CFF', '#FF7A59', '#FFD166'];
const MODULE_ORDER = ['rpm', 'throttle', 'fuel', 'engine', 'nitro', 'telltales', 'altitude', 'notices'];

class SettingsPanel {
  constructor(layer, app) {
    this.layer = layer;
    this.app = app;
    this.q = (s) => layer.querySelector(s);
    this.editing = false;
    this.rules = {};
    this.bind();
  }

  bind() {
    const layer = this.layer;
    layer.addEventListener('click', (e) => {
      const unit = e.target.closest('[data-unit-option]');
      if (unit) return this.app.updateSettings((s) => (s.unit = unit.dataset.unitOption));
      const swatch = e.target.closest('[data-swatch]');
      if (swatch) return this.app.updateSettings((s) => (s.accent = swatch.dataset.swatch));
      const action = e.target.closest('[data-action]');
      if (!action) return undefined;
      switch (action.dataset.action) {
        case 'close': return this.app.closeSettings();
        case 'test-sound': return FC.Audio.play('belt_on');
        case 'edit-layout': return this.setEditing(!this.editing);
        case 'reset-layout':
          return this.app.updateSettings((s) => {
            delete s.cluster.x; delete s.cluster.y; delete s.location.x; delete s.location.y;
          });
        case 'reset-scale': return this.app.updateSettings((s) => (s.cluster.scale = 1));
        case 'reset-loc-scale': {
          const def = this.rules.locationDefault;
          return this.app.updateSettings((s) => (s.location.scale = (def && FC.isNum(def.scale)) ? def.scale : 1));
        }
        case 'reset': return this.app.resetSettings();
        default: return undefined;
      }
    });

    const hex = this.q('[data-hex]');
    hex.addEventListener('input', () => {
      const value = hex.value.replace(/[^0-9a-f]/gi, '').slice(0, 6);
      if (value !== hex.value) hex.value = value;
      const valid = value.length === 6;
      hex.parentElement.dataset.invalid = String(!valid && value.length > 0);
      if (valid) this.app.updateSettings((s) => (s.accent = `#${value.toUpperCase()}`));
    });

    this.q('[data-loc-toggle]').addEventListener('change', (e) => {
      this.app.updateSettings((s) => (s.location.enabled = e.target.checked));
    });

    this.q('[data-values-toggle]').addEventListener('change', (e) => {
      this.app.updateSettings((s) => (s.values = e.target.checked));
    });

    const volume = this.q('[data-volume]');
    volume.addEventListener('input', () => {
      this.app.updateSettings((s) => (s.volume = (Number(volume.value) / 100) * (this.rules.maxVolume || 1)));
    });

    layer.querySelectorAll('[data-scale]').forEach((input) => {
      input.addEventListener('input', () => {
        const name = input.dataset.scale;
        this.app.updateSettings((s) => (s[name].scale = Number(input.value) / 100));
      });
    });

    layer.querySelectorAll('[data-opacity]').forEach((input) => {
      input.addEventListener('input', () => {
        const name = input.dataset.opacity;
        this.app.updateSettings((s) => (s[name].opacity = Number(input.value) / 100));
      });
    });

    this.q('[data-module-toggles]').addEventListener('change', (e) => {
      const name = e.target.dataset.module;
      if (name) this.app.updateSettings((s) => (s.modules[name] = e.target.checked));
    });

    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !this.layer.hidden) {
        e.preventDefault();
        if (this.editing) this.setEditing(false); else this.app.closeSettings();
      }
    });
  }

  build(rules) {
    this.rules = { ...(rules || {}) };
    this.rules.locationAvailable = !(this.rules.features && this.rules.features.location === false);
    this.layer.querySelectorAll('[data-rule]').forEach((el) => {
      el.hidden = this.rules[el.dataset.rule] === false;
    });

    const swatches = this.q('[data-swatches]');
    swatches.innerHTML = '';
    SWATCHES.forEach((color) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'fc-swatch';
      b.dataset.swatch = color;
      b.style.setProperty('--sw', color);
      b.setAttribute('aria-label', color);
      swatches.appendChild(b);
    });

    const features = this.rules.features || {};
    const toggles = this.q('[data-module-toggles]');
    toggles.innerHTML = '';
    MODULE_ORDER.forEach((name) => {
      if (name === 'nitro' && features.nitro === false) return;
      const label = document.createElement('label');
      label.className = 'fc-toggle';
      label.innerHTML = `<span>${FC.t(`module.${name}`)}</span><input type="checkbox" data-module="${name}"><i></i>`;
      toggles.appendChild(label);
    });

    const min = Math.round((this.rules.scaleMin || 0.8) * 100);
    const max = Math.round((this.rules.scaleMax || 1.5) * 100);
    this.layer.querySelectorAll('[data-scale]').forEach((input) => {
      input.min = String(min);
      input.max = String(max);
    });
    const minOpacity = Math.round((this.rules.opacityMin || 0.4) * 100);
    this.layer.querySelectorAll('[data-opacity]').forEach((input) => {
      input.min = String(minOpacity);
    });
    FC.setText(this.q('[data-version]'), `v${FC.version}`);
    FC.applyI18n(this.layer);
  }

  render(s) {
    this.layer.querySelectorAll('[data-unit-option]').forEach((b) => {
      b.setAttribute('aria-checked', String(b.dataset.unitOption === s.unit));
    });
    this.layer.querySelectorAll('[data-swatch]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.swatch.toUpperCase() === s.accent.toUpperCase()));
    });
    const hex = this.q('[data-hex]');
    if (document.activeElement !== hex) {
      hex.value = s.accent.replace('#', '').toUpperCase();
      hex.parentElement.dataset.invalid = 'false';
    }
    this.q('[data-values-toggle]').checked = !!s.values;
    this.layer.querySelectorAll('[data-module]').forEach((input) => {
      input.checked = s.modules[input.dataset.module] !== false;
    });

    const maxVolume = this.rules.maxVolume || 1;
    const vol = Math.round((s.volume / maxVolume) * 100);
    this.setRange(this.q('[data-volume]'), vol, `${Math.round(s.volume * 100)}%`, this.q('[data-volume-out]'));
    this.q('[data-loc-toggle]').checked = s.location.enabled !== false;
    ['cluster', 'location'].forEach((name) => {
      const value = Math.round(s[name].scale * 100);
      this.setRange(this.q(`[data-scale="${name}"]`), value, `${value}%`, this.q(`[data-scale-out="${name}"]`));
      const opacityInput = this.q(`[data-opacity="${name}"]`);
      if (opacityInput) {
        const opacity = Math.round((s[name].opacity || 1) * 100);
        this.setRange(opacityInput, opacity, `${opacity}%`, this.q(`[data-opacity-out="${name}"]`));
      }
    });
  }

  setRange(input, value, label, output) {
    if (document.activeElement !== input) input.value = String(value);
    const min = Number(input.min);
    const max = Number(input.max);
    input.style.setProperty('--fill', `${((Number(input.value) - min) / (max - min || 1)) * 100}%`);
    FC.setText(output, label);
  }

  setEditing(on) {
    this.editing = !!on;
    this.app.layout.setEditing(this.editing);
    const button = this.q('[data-action="edit-layout"]');
    button.setAttribute('aria-pressed', String(this.editing));
    FC.setText(button, FC.t(this.editing ? 'settings.moving' : 'settings.move'));
    this.q('[data-layout-hint]').hidden = !this.editing;
  }

  open(settings, rules) {
    this.build(rules);
    this.render(settings);
    this.layer.hidden = false;
    this.setEditing(false);
    const first = this.layer.querySelector('button');
    if (first) first.focus({ preventScroll: true });
  }

  close() {
    this.setEditing(false);
    this.layer.hidden = true;
  }
}

FC.SettingsPanel = SettingsPanel;

// ── 65-admin.js
// Menú de administración (/carhudadmin). Edita una copia local: Guardar la envía
// al servidor (que vuelve a comprobar permisos, tipos y límites), Cancelar la
// descarta y «Predeterminados» rellena la sección con los valores de config.lua
// (sin guardar hasta pulsar Guardar). El esquema llega desde Lua.
const ADMIN_SECTIONS = ['seatbelt', 'engine', 'lights', 'cruise', 'nitro'];

class AdminPanel {
  constructor(layer) {
    this.layer = layer;
    this.q = (s) => layer.querySelector(s);
    this.tabs = this.q('[data-admin-tabs]');
    this.body = this.q('[data-admin-body]');
    this.status = this.q('[data-admin-status]');
    this.section = 'seatbelt';
    this.fields = [];
    this.values = {};
    this.defaults = {};
    this.saved = {};
    this.errors = {};
    this.busy = false;

    layer.addEventListener('click', (e) => {
      const tab = e.target.closest('[data-admin-tab]');
      if (tab) return this.showSection(tab.dataset.adminTab);
      const action = e.target.closest('[data-admin-action]');
      if (!action) return undefined;
      if (action.dataset.adminAction === 'cancel') return this.close();
      if (action.dataset.adminAction === 'save') return this.save();
      if (action.dataset.adminAction === 'defaults') return this.restoreSection();
      return undefined;
    });
    layer.addEventListener('input', (e) => this.onInput(e));
    layer.addEventListener('change', (e) => this.onInput(e));
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !this.layer.hidden) {
        e.preventDefault();
        this.close();
      }
    });
  }

  open(msg) {
    this.fields = msg.fields || [];
    this.keys = msg.keys || [];
    // Las listas vacías pueden llegar de Lua como objeto ({}): se normalizan a [].
    const normalize = (src) => {
      const out = JSON.parse(JSON.stringify(src || {}));
      this.fields.forEach((f) => {
        if ((f.type === 'list' || f.type === 'models') && !Array.isArray(out[f.id])) out[f.id] = [];
      });
      return out;
    };
    this.defaults = normalize(msg.defaults);
    this.saved = normalize(msg.values);
    this.values = normalize(msg.values);
    this.errors = {};
    this.busy = false;
    this.renderTabs();
    this.showSection(this.section);
    this.setStatus('', '');
    this.layer.hidden = false;
    FC.applyI18n(this.layer);
    FC.post('adminOpened', {});
  }

  close(fromGame) {
    if (this.layer.hidden) return;
    this.layer.hidden = true;
    if (!fromGame) FC.post('adminClose', {});
  }

  label(id) { return FC.t(`admin.f.${id}`); }
  hint(id) { const key = `admin.h.${id}`; const text = FC.t(key); return text === key ? '' : text; }

  renderTabs() {
    this.tabs.innerHTML = '';
    ADMIN_SECTIONS.forEach((name) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.setAttribute('role', 'tab');
      b.dataset.adminTab = name;
      b.textContent = FC.t(`admin.s.${name}`);
      this.tabs.appendChild(b);
    });
  }

  showSection(name) {
    this.section = name;
    this.tabs.querySelectorAll('[data-admin-tab]').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.adminTab === name)));
    this.body.innerHTML = '';
    let group = null;
    this.fields.filter((f) => f.section === name).forEach((field) => {
      const heading = FC.t(`admin.g.${field.id}`);
      if (heading !== `admin.g.${field.id}`) {
        group = document.createElement('section');
        group.className = 'fc-group';
        group.innerHTML = `<h2>${heading}</h2>`;
        this.body.appendChild(group);
      }
      if (!group) {
        group = document.createElement('section');
        group.className = 'fc-group';
        this.body.appendChild(group);
      }
      group.appendChild(this.renderField(field));
    });
    this.refreshDerived();
  }

  renderField(field) {
    const row = document.createElement('div');
    row.className = 'fc-admin-field';
    row.dataset.field = field.id;
    let value = this.values[field.id];
    // Una lista vacía puede llegar de Lua como objeto: se normaliza a array.
    if ((field.type === 'list' || field.type === 'models') && !Array.isArray(value)) value = this.values[field.id] = [];
    const label = `<span class="fc-admin-label">${this.label(field.id)}<i class="fc-admin-dot" title="${FC.t('admin.modified')}"></i></span>`;
    let control = '';
    if (field.type === 'bool') {
      control = `<label class="fc-toggle">${label}<input type="checkbox" data-input ${value ? 'checked' : ''}><i></i></label>`;
      row.innerHTML = control;
    } else if (field.type === 'number' || field.type === 'int') {
      row.innerHTML = `${label}<div class="fc-range-row"><input type="range" data-input min="${field.min}" max="${field.max}" step="${field.step}" value="${value}"><output data-out></output></div>`;
    } else if (field.type === 'key') {
      const options = this.keys.map((k) => `<option value="${k}" ${k === value ? 'selected' : ''}>${k}</option>`).join('');
      row.innerHTML = `${label}<select class="fc-select" data-input>${options}</select>`;
    } else if (field.type === 'list') {
      const chips = field.options.map((o) => `<label class="fc-chip"><input type="checkbox" data-option="${o}" ${(value || []).includes(o) ? 'checked' : ''}><span>${FC.t(`admin.cat.${o}`)}</span></label>`).join('');
      row.innerHTML = `${label}<div class="fc-chips" data-input>${chips}</div>`;
    } else if (field.type === 'models') {
      row.innerHTML = `${label}<input type="text" class="fc-text" data-input spellcheck="false" placeholder="${FC.t('admin.modelsPlaceholder')}" value="${(value || []).join(', ')}">`;
    }
    const hint = this.hint(field.id);
    if (hint) row.insertAdjacentHTML('beforeend', `<p class="fc-hint">${hint}</p>`);
    row.insertAdjacentHTML('beforeend', '<p class="fc-admin-error" data-error hidden></p>');
    this.decorate(row, field);
    return row;
  }

  format(field, value) {
    if (field.unit === 'ratio') return `${Math.round(value * 100)} %`;
    if (field.unit === 'x') return `${Number(value).toFixed(2)}×`;
    if (field.unit === 'unit') return `${value} km/h · mph`;
    const decimals = field.step < 1 ? (field.step < 0.1 ? 2 : 1) : 0;
    return `${Number(value).toFixed(decimals)} ${field.unit || ''}`.trim();
  }

  decorate(row, field) {
    const value = this.values[field.id];
    const out = row.querySelector('[data-out]');
    if (out) out.textContent = this.format(field, value);
    const range = row.querySelector('input[type="range"]');
    if (range) range.style.setProperty('--fill', `${((value - field.min) / (field.max - field.min || 1)) * 100}%`);
    const changed = JSON.stringify(value) !== JSON.stringify(this.defaults[field.id]);
    row.dataset.modified = String(changed);
    const err = row.querySelector('[data-error]');
    const e = this.errors[field.id];
    err.hidden = !e;
    err.textContent = e ? FC.t(`admin.err.${e}`) : '';
  }

  onInput(e) {
    const row = e.target.closest('[data-field]');
    if (!row) return;
    const field = this.fields.find((f) => f.id === row.dataset.field);
    let value;
    if (field.type === 'bool') value = e.target.checked;
    else if (field.type === 'number' || field.type === 'int') value = Number(e.target.value);
    else if (field.type === 'key') value = e.target.value;
    else if (field.type === 'list') value = field.options.filter((o) => row.querySelector(`[data-option="${o}"]`).checked);
    else if (field.type === 'models') value = e.target.value.split(/[,\s]+/).map((s) => s.trim().toLowerCase()).filter(Boolean);
    this.values[field.id] = value;
    delete this.errors[field.id];
    this.decorate(row, field);
    this.refreshDerived();
    this.setStatus(this.dirty() ? FC.t('admin.unsaved') : '', 'info');
  }

  // Ayuda calculada: deceleración equivalente del umbral de choque.
  refreshDerived() {
    const delta = this.values['Seatbelt.ejection.minDelta'];
    const windowMs = this.values['Seatbelt.ejection.window'];
    const row = this.body.querySelector('[data-field="Seatbelt.ejection.window"] .fc-hint');
    if (row && FC.isNum(delta) && FC.isNum(windowMs) && windowMs > 0) {
      const g = (delta / 3.6) / (windowMs / 1000) / 9.81;
      row.textContent = FC.t('admin.h.Seatbelt.ejection.window', { g: g.toFixed(1), d: delta, w: windowMs });
    }
  }

  dirty() {
    return JSON.stringify(this.values) !== JSON.stringify(this.saved);
  }

  restoreSection() {
    this.fields.filter((f) => f.section === this.section).forEach((f) => {
      this.values[f.id] = JSON.parse(JSON.stringify(this.defaults[f.id]));
      delete this.errors[f.id];
    });
    this.showSection(this.section);
    this.setStatus(FC.t('admin.defaultsApplied'), 'info');
  }

  save() {
    if (this.busy) return;
    if (!this.dirty()) { this.setStatus(FC.t('admin.nothing'), 'info'); return; }
    this.busy = true;
    this.setStatus(FC.t('admin.saving'), 'info');
    FC.post('adminSave', { values: this.values });
  }

  result(res) {
    this.busy = false;
    if (res.ok) {
      this.saved = JSON.parse(JSON.stringify(res.values || this.values));
      this.fields.forEach((f) => {
        if ((f.type === 'list' || f.type === 'models') && !Array.isArray(this.saved[f.id])) this.saved[f.id] = [];
      });
      this.values = JSON.parse(JSON.stringify(this.saved));
      this.errors = {};
      this.showSection(this.section);
      this.setStatus(FC.t('admin.saved', { n: res.changed || 0 }), 'ok');
      return;
    }
    this.errors = {};
    let general = '';
    (res.errors || []).forEach((e) => {
      if (e.id === '*') general = FC.t(`admin.err.${e.error}`);
      else this.errors[e.id] = e.error;
    });
    const first = (res.errors || []).find((e) => e.id !== '*');
    if (first) {
      const field = this.fields.find((f) => f.id === first.id);
      if (field && field.section !== this.section) this.showSection(field.section);
      else this.showSection(this.section);
    }
    this.setStatus(general || FC.t('admin.invalid'), 'error');
  }

  setStatus(text, kind) {
    this.status.hidden = !text;
    this.status.textContent = text;
    this.status.dataset.kind = kind || 'info';
  }
}

FC.AdminPanel = AdminPanel;

// ── 67-crashdiag.js
// Diagnóstico de expulsión: muestras de velocidad, variación detectada,
// evidencia de colisión y motivo de la decisión. Solo texto; se actualiza como
// mucho 10 veces por segundo y solo mientras está activado.
class CrashDiag {
  constructor(el) {
    this.el = el;
  }

  update(data) {
    if (!data) {
      this.el.hidden = true;
      return;
    }
    this.el.hidden = false;
    if (data.dv === undefined) {
      this.el.innerHTML = `<b>${FC.t('diag.title')}</b><p>${FC.t('diag.waiting')}</p>`;
      return;
    }
    const n = (v, d = 0) => (FC.isNum(v) ? v.toFixed(d) : '—');
    const mark = (ok) => `<i class="${ok ? 'ok' : 'no'}">${ok ? '✓' : '✗'}</i>`;
    const samples = (data.samples || [])
      .map((s) => `<span>−${s.dt} ms · ${s.kmh} km/h · ${s.hdg}°</span>`)
      .join('');
    const collision = data.collisionAge >= 0 ? FC.t('diag.collisionAgo', { ms: data.collisionAge }) : FC.t('diag.none');
    const dec = data.decision;
    const decision = dec
      ? `<p class="fc-diag-dec ${dec.reason === 'impact' ? 'hit' : ''}">${FC.t(`diag.reason.${dec.reason}`)} · Δv ${n(dec.dv)} km/h · ${FC.t('diag.impact')} ${n(dec.impact)} km/h · ${FC.t('diag.collision')} ${dec.evidence ? '✓' : '✗'}</p>`
      : `<p class="fc-diag-dec">${FC.t('diag.noDecision')}</p>`;
    this.el.innerHTML = `
      <b>${FC.t('diag.title')}</b>
      <p>${FC.t('diag.now')} ${n(data.speed)} km/h · ${n(data.heading)}°</p>
      <p class="fc-diag-samples">${FC.t('diag.samples', { ms: data.window })}${samples}</p>
      <p>${mark(data.dv >= data.minDelta)} Δv ${n(data.dv)} km/h (≥ ${n(data.minDelta)})</p>
      <p>${mark(data.ratio >= data.minRatio)} ${FC.t('diag.ratio')} ${n(data.ratio, 2)} (≥ ${n(data.minRatio, 2)})</p>
      <p>${mark(data.impact >= data.minSpeed)} ${FC.t('diag.impact')} ${n(data.impact)} km/h (≥ ${n(data.minSpeed)})</p>
      <p>${mark(data.evidence)} ${FC.t('diag.collision')}: ${collision} · ${FC.t('diag.body')} −${n(Math.max(data.bodyDrop || 0, 0))}</p>
      <p>${mark(!data.belted)} ${FC.t(data.belted ? 'diag.belted' : 'diag.unbelted')} · ${mark(data.allowed && data.enabled)} ${FC.t(data.allowed && data.enabled ? 'diag.allowed' : 'diag.notAllowed')}</p>
      <p>${FC.t('diag.state')}: ${FC.t(`diag.reason.${data.reason}`)}</p>
      ${decision}`;
  }
}

FC.CrashDiag = CrashDiag;

// ── 68-location.js
// Ubicación sobre el minimapa: calle (principal), zona (debajo) y rumbo a la
// izquierda. Sin animaciones repetitivas: solo una transición corta del rumbo
// cuando cambia. Los nombres largos se recortan con puntos suspensivos.
// Su visibilidad llega en el mismo mensaje que la del HUD ('visible') y se funde
// con la misma capa (.fc-hud) que el velocímetro.
class LocationBox {
  constructor(el) {
    this.el = el;
    this.arrow = el.querySelector('[data-loc-arrow]');
    this.sectorEl = el.querySelector('[data-loc-sector]');
    this.mainEl = el.querySelector('[data-loc-main]');
    this.subEl = el.querySelector('[data-loc-sub]');
    this.arrow.innerHTML = FC.icons.navigation;
    this.luaVisible = false;
    this.enabled = true;
    this.sector = 0;
    this.rotation = 0; // acumulada: el giro 359° → 1° no da la vuelta entera
    this.onLayoutChange = null;
  }

  setEnabled(enabled) {
    this.enabled = enabled !== false;
    this.refresh();
  }

  // Con el menú de ajustes abierto se muestra (aunque Lua la oculte, p. ej. a pie)
  // para poder colocarla y escalarla; sin datos aún, con un rótulo de posición.
  setPreview(on) {
    this.preview = !!on;
    if (this.preview && !this.mainEl.textContent) {
      this.placeholder = true;
      FC.setText(this.mainEl, FC.t('settings.location'));
      this.subEl.hidden = true;
    } else if (!this.preview && this.placeholder) {
      this.placeholder = false;
      FC.setText(this.mainEl, '');
    }
    this.refresh();
  }

  shown() {
    return this.el.dataset.show === 'true';
  }

  refresh() {
    const show = (this.luaVisible || this.preview) && this.enabled && !!this.mainEl.textContent;
    if (this.shown() !== show) {
      this.el.dataset.show = String(show);
      if (show && this.onLayoutChange) this.onLayoutChange();
    }
  }

  update(msg) {
    if ('visible' in msg) this.luaVisible = !!msg.visible;
    if ('sector' in msg) {
      this.sector = msg.sector;
      FC.setText(this.sectorEl, FC.isNum(msg.sector) ? FC.t('loc.sector.' + msg.sector) : '');
    }
    if ('bearing' in msg && FC.isNum(msg.bearing)) {
      const current = ((this.rotation % 360) + 360) % 360;
      this.rotation += ((msg.bearing - current + 540) % 360) - 180;
      this.arrow.style.transform = `rotate(${this.rotation.toFixed(1)}deg)`;
    }
    if ('main' in msg) {
      this.placeholder = false;
      FC.setText(this.mainEl, msg.main || '');
      this.mainEl.title = msg.main || '';
      FC.setText(this.subEl, msg.sub || '');
      this.subEl.title = msg.sub || '';
      this.subEl.hidden = !msg.sub;
    }
    const label = [this.mainEl.textContent, this.subEl.hidden ? '' : this.subEl.textContent, this.sectorEl.textContent].filter(Boolean).join(', ');
    this.el.setAttribute('aria-label', label);
    const wasShown = this.shown();
    this.refresh();
    // Con una o dos líneas cambia el alto: se reancla para mantener la separación.
    if ('main' in msg && wasShown && this.onLayoutChange) this.onLayoutChange();
  }

  relabel() {
    FC.setText(this.sectorEl, FC.isNum(this.sector) ? FC.t('loc.sector.' + this.sector) : '');
  }
}

FC.LocationBox = LocationBox;

// ── 70-audio.js
// Sonidos locales (html/sounds). Volumen del jugador, limitado por el servidor.
FC.Audio = {
  volume: 0.6,
  cache: {},
  get(name) {
    if (!this.cache[name]) {
      const audio = new Audio(`${FC.assetBase || ''}sounds/${name}.wav`);
      audio.preload = 'auto';
      this.cache[name] = audio;
    }
    return this.cache[name];
  },
  preload(names) {
    names.forEach((n) => this.get(n));
  },
  play(name, gain) {
    const volume = FC.clamp(this.volume * (FC.isNum(gain) ? gain : 1), 0, 1);
    if (volume <= 0) return;
    const audio = this.get(name);
    try {
      audio.pause();
      audio.currentTime = 0;
      audio.volume = volume;
      const result = audio.play();
      if (result && result.catch) result.catch(() => {});
    } catch (e) {
      /* audio no disponible: se ignora */
    }
  },
};

// ── 90-app.js
// Enrutador de mensajes y bucle de animación. El bucle solo corre mientras el
// HUD es visible y queda algo por interpolar; en reposo no consume fotogramas.
const DEFAULT_SETTINGS = {
  unit: 'kmh',
  accent: '#FE3555',
  values: false,
  volume: 0.6,
  modules: { rpm: true, throttle: true, fuel: true, engine: true, nitro: true, telltales: true, altitude: true, notices: true },
  cluster: { scale: 1, opacity: 1 },
  location: { enabled: true, scale: 1 },
};

const LAYOUT_PROFILE = {
  category: 'car', gear: true, rpm: true, throttle: true, fuel: true, engine: true, nitro: false,
  scaleKmh: 260, redline: 8000, telltales: { belt: true, lights: true, cruise: true, indicators: true },
};

const clone = (o) => JSON.parse(JSON.stringify(o));

const App = {
  visible: false,
  settingsOpen: false,
  raf: 0,
  last: 0,
  profile: null,

  init() {
    const root = document.getElementById('fc-root');
    this.root = root;
    FC.mountIcons(root);
    FC.applyI18n(root);
    this.cluster = new FC.Cluster(document.getElementById('fc-cluster'));
    this.strip = new FC.Status(document.getElementById('fc-cluster'));
    this.layout = new FC.Layout(
      root,
      { cluster: document.getElementById('fc-cluster') },
      (name, point) => this.updateSettings((s) => Object.assign(s[name], point)),
    );
    this.strip.onLayoutChange = () => this.refreshFooter();
    this.cluster.onFooterChange = () => this.refreshFooter();
    this.panel = new FC.SettingsPanel(root.querySelector('[data-settings]'), this);
    this.admin = new FC.AdminPanel(root.querySelector('[data-admin]'));
    this.diag = new FC.CrashDiag(root.querySelector('[data-diag]'));
    this.location = new FC.LocationBox(root.querySelector('#fc-location'));
    this.layout.setLocationEl(this.location.el);
    this.location.onLayoutChange = () => this.layout.placeLocation();
    this.rules = {};
    this.settings = clone(DEFAULT_SETTINGS);
    this.applySettings(this.settings);
    this.setProfile(LAYOUT_PROFILE);
    FC.Audio.preload(['belt_on', 'belt_off', 'belt_warn']);
    this.frame = this.frame.bind(this);
    window.addEventListener('message', (e) => this.handle(e.data));
    FC.post('ready', {});
  },

  handle(msg) {
    if (!msg || typeof msg !== 'object') return;
    switch (msg.t) {
      case 'init':
        FC.setLocale(msg.lang, msg.strings, msg.fallback);
        FC.applyI18n(this.root);
        this.location.relabel();
        this.rules = msg.rules || {};
        this.layout.locDefault = this.rules.locationDefault || null;
        if (msg.thresholds) this.strip.thresholds = msg.thresholds;
        if (msg.settings) this.applySettings(msg.settings);
        this.setProfile(this.profile || LAYOUT_PROFILE);
        break;
      case 'settings':
        this.applySettings(msg.settings);
        break;
      case 'visible': {
        // Una sola orden para todo el HUD: la ubicación (y sus datos al aparecer)
        // se aplica en la misma tarea que el velocímetro, así comparten fotograma
        // y transición.
        // Al ocultarse el HUD no se toca su estado propio: la oculta la capa común, a la
        // vez que al velocímetro (si se ocultara aquí, desaparecería antes que él).
        const loc = msg.v ? { visible: !!msg.loc } : {};
        ['main', 'sub', 'sector', 'bearing'].forEach((k) => { if (k in msg) loc[k] = msg[k]; });
        this.location.update(loc);
        this.setVisible(!!msg.v);
        break;
      }
      case 'profile':
        this.setProfile(msg.profile);
        break;
      case 'f':
        this.cluster.setFast(msg);
        this.kick();
        break;
      case 's':
        this.strip.setSlow(msg);
        if (msg.tt) this.cluster.setTelltales(msg.tt);
        this.kick();
        break;
      case 'safe':
        this.layout.setSafeZone(msg.safe, msg.mm, msg.gap);
        break;
      case 'notice':
        this.notice(msg);
        break;
      case 'sound':
        FC.Audio.play(msg.name, msg.gain);
        break;
      case 'openSettings':
        this.openSettings();
        break;
      case 'closeSettings':
        this.closeSettings(true);
        break;
      case 'location':
        this.location.update(msg);
        break;
      case 'crashDiag':
        this.diag.update(msg.data);
        break;
      case 'adminOpen':
        if (this.settingsOpen) this.closeSettings(true);
        this.admin.open(msg);
        break;
      case 'adminResult':
        this.admin.result(msg.result || {});
        break;
      case 'adminClose':
        this.admin.close(true);
        break;
      case 'perf':
        this.startPerf(msg.ms || 10000);
        break;
      default:
        break;
    }
  },

  notice(msg) {
    let text = msg.text;
    if (!text && msg.key) {
      const vars = { ...(msg.vars || {}) };
      if (FC.isNum(vars.speed)) {
        const mph = this.settings.unit === 'mph';
        vars.v = Math.round(vars.speed * (mph ? FC.MPH : FC.KMH));
        vars.u = mph ? 'MPH' : 'KM/H';
      }
      text = FC.t(msg.key, vars);
    }
    if (text) this.strip.flash(text, msg.kind, msg.ms);
  },

  setProfile(profile) {
    this.profile = profile || LAYOUT_PROFILE;
    this.cluster.setProfile(this.profile);
    this.strip.setProfile(this.profile);
    this.layout.compact = !!this.profile.compact;
    this.layout.apply();
    this.cluster.snap();
  },

  // Fila inferior: separador solo si hay testigos/altitud y combustible/motor; sin nada, se oculta.
  refreshFooter() {
    const footer = this.root.querySelector('[data-footer]');
    const left = this.cluster.footerLeftVisible();
    const right = this.strip.minisVisible();
    this.root.querySelector('[data-divider]').hidden = !(left && right);
    footer.hidden = !(left || right);
    this.layout.apply();
  },

  effectiveVisible() {
    return this.visible || this.settingsOpen;
  },

  setVisible(v) {
    this.visible = v;
    this.refreshVisibility();
  },

  refreshVisibility() {
    const show = this.effectiveVisible();
    if (this.root.dataset.visible === String(show)) return;
    this.root.dataset.visible = String(show);
    if (show) {
      this.layout.apply();
      this.cluster.snap();
      this.kick();
    } else if (this.raf) {
      cancelAnimationFrame(this.raf);
      this.raf = 0;
    }
  },

  applySettings(s) {
    const next = { ...clone(DEFAULT_SETTINGS), ...clone(s || {}) };
    next.modules = { ...DEFAULT_SETTINGS.modules, ...(s && s.modules) };
    next.cluster = { ...DEFAULT_SETTINGS.cluster, ...(s && s.cluster) };
    next.location = { ...DEFAULT_SETTINGS.location, ...(s && s.location) };
    this.settings = next;
    this.root.dataset.values = String(!!next.values);
    const palette = FC.applyAccent(next.accent);
    this.cluster.setPalette(palette);
    this.strip.setPalette(palette);
    this.cluster.setModules(next.modules);
    this.strip.setModules(next.modules);
    this.cluster.setUnit(next.unit);
    FC.Audio.volume = FC.clamp(next.volume, 0, 1);
    this.location.setEnabled(next.location.enabled);
    this.layout.setSettings(next);
    if (this.settingsOpen) this.panel.render(next);
  },

  updateSettings(mutate) {
    const next = clone(this.settings);
    mutate(next);
    this.applySettings(next);
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => FC.post('save', { settings: this.settings }), 250);
  },

  resetSettings() {
    clearTimeout(this.saveTimer);
    FC.post('reset', {});
  },

  openSettings() {
    // A pie el HUD se muestra solo para colocarlo: a cero, sin datos inventados.
    if (!this.visible) {
      this.cluster.setFast({ s: 0, r: 0, p: 0 });
      this.cluster.snap();
    }
    this.settingsOpen = true;
    this.panel.open(this.settings, this.rules);
    this.location.setPreview(true);
    this.layout.placeLocation();
    this.refreshVisibility();
    FC.post('opened', {});
  },

  closeSettings(fromGame) {
    if (!this.settingsOpen) return;
    this.settingsOpen = false;
    this.panel.close();
    this.location.setPreview(false);
    this.refreshVisibility();
    clearTimeout(this.saveTimer);
    if (!fromGame) FC.post('close', { settings: this.settings });
  },

  kick() {
    if (!this.raf && this.effectiveVisible()) {
      this.last = performance.now();
      this.raf = requestAnimationFrame(this.frame);
    }
  },

  frame(ts) {
    const t0 = performance.now();
    const dt = Math.min(Math.max((ts - this.last) / 1000, 0), 0.1);
    this.last = ts;
    const a = this.cluster.step(dt);
    const b = this.strip.step(dt);
    this.raf = (a || b) && this.effectiveVisible() ? requestAnimationFrame(this.frame) : 0;
    if (this.perf) this.perf.record(performance.now() - t0);
  },

  // Medición de coste de la NUI: tiempo de script por fotograma animado.
  startPerf(ms) {
    const perf = { total: 0, peak: 0, frames: 0, started: performance.now(), ticks: 0 };
    perf.record = (cost) => {
      perf.total += cost;
      perf.frames += 1;
      if (cost > perf.peak) perf.peak = cost;
    };
    this.perf = perf;
    const counter = () => {
      if (this.perf !== perf) return;
      perf.ticks += 1;
      if (performance.now() - perf.started < ms) requestAnimationFrame(counter);
    };
    requestAnimationFrame(counter);
    setTimeout(() => {
      if (this.perf !== perf) return;
      this.perf = null;
      FC.post('perf', {
        avg: perf.frames ? perf.total / perf.frames : 0,
        peak: perf.peak,
        frames: perf.frames,
        ticks: perf.ticks,
      });
    }, ms);
  },
};

FC.App = App;
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => App.init());
else App.init();
})();
