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
