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
