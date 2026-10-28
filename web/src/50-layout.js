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
