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
