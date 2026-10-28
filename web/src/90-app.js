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
