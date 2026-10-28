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
