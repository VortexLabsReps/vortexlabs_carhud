// Vista previa: simula un vehículo y envía a la NUI los mismos mensajes que
// client/telemetry.lua. Velocidad, RPM, marcha y acelerador salen de un modelo
// físico simple propio de la simulación; el HUD no deriva unos de otros.
(() => {
  const q = (s) => document.querySelector(s);
  const hud = q('[data-hud]');
  const screen = q('[data-screen]');
  const map = q('[data-map]');
  const log = q('[data-log]');

  const PROFILES = {
    car: { category: 'car', gear: true, rpm: true, throttle: true, fuel: true, engine: true, nitro: true, scaleKmh: 260, redline: 8000, telltales: { belt: true, lights: true, cruise: true, indicators: true } },
    motorcycle: { category: 'motorcycle', compact: true, gear: true, rpm: true, throttle: true, fuel: true, engine: true, nitro: true, scaleKmh: 240, redline: 11000, telltales: { belt: false, lights: true, cruise: true, indicators: true } },
    boat: { category: 'boat', gear: false, rpm: true, throttle: true, fuel: true, engine: true, nitro: false, scaleKmh: 120, redline: 6000, telltales: { belt: false, lights: true, cruise: false, indicators: false } },
    plane: { category: 'plane', aircraft: 'plane', gear: false, rpm: false, throttle: true, fuel: true, engine: true, nitro: false, scaleKmh: 500, telltales: {} },
    heli: { category: 'heli', aircraft: 'heli', gear: false, rpm: false, throttle: true, fuel: true, engine: true, nitro: false, scaleKmh: 300, telltales: {} },
  };
  const RATIOS = [3.0, 3.4, 2.2, 1.6, 1.25, 1.0, 0.82];

  const sim = {
    category: 'car', scenario: 'drive', manualPedal: 0.6, t: 0,
    speed: 0, gear: 1, rpm: 0.2, pedal: 0, reverse: false,
    belt: true, lights: 'low', ind: 0, cruise: false, cruiseTarget: 0, engineOn: true, nitroMode: 'equipped', nitroOn: false,
    warnings: false, destroyed: false, fuelMode: 'provider',
    fuel: 68, eng: 92, nitroAmt: 74, msl: 120, agl: 2, vs: 0,
  };
  const prefsKey = 'vortexlabs_carhud.preview.settings';
  let settings = null;
  try { settings = JSON.parse(localStorage.getItem(prefsKey) || 'null'); } catch (e) { settings = null; }
  let res = [1920, 1080];
  let safe = 1;
  let ready = false;
  const sent = {};

  const send = (msg) => hud.contentWindow && hud.contentWindow.postMessage(msg, '*');
  const write = (line) => {
    log.textContent = `${line}\n${log.textContent}`.slice(0, 1500);
  };

  // Idioma de la vista previa: ?lang=es (por defecto inglés, como la distribución).
  const lang = new URLSearchParams(location.search).get('lang') || 'en';
  const locales = Promise.all([lang, 'en'].map((l) => fetch(`../locales/${l}.json`).then((r) => r.json())));

  // ── Respuestas a las llamadas de la NUI (equivalente a client/nui.lua)
  window.addEventListener('message', (e) => {
    const m = e.data;
    if (!m || !m.fcPost) return;
    write(`${m.fcPost} ${JSON.stringify(m.data).slice(0, 120)}`);
    if (m.fcPost === 'ready') {
      ready = true;
      locales.then(([main, en]) => {
        send({ t: 'init', lang, strings: main.ui, fallback: en.ui, settings, thresholds: { fuel: 15, engine: 35 }, rules: { allowUnit: true, allowColor: true, allowLayout: true, allowModules: true, scaleMin: 0.8, scaleMax: 1.5, opacityMin: 0.4, maxVolume: 1, locationDefault: { x: 20 / 1080, y: -37 / 1080, scale: 1.02 }, features: { nitro: true, seatbelt: true } } });
        applyCategory();
        sendSafe();
        sendPlace('city');
      });
    } else if (m.fcPost === 'save' || m.fcPost === 'close') {
      settings = m.data.settings;
      try { localStorage.setItem(prefsKey, JSON.stringify(settings)); } catch (err) { /* sin almacenamiento */ }
      send({ t: 'settings', settings });
    } else if (m.fcPost === 'reset') {
      settings = null;
      try { localStorage.removeItem(prefsKey); } catch (err) { /* sin almacenamiento */ }
      send({ t: 'settings', settings: {} });
    }
  });

  function profile() {
    return PROFILES[sim.category];
  }

  // Como en el juego: una sola orden de visibilidad para el HUD y la ubicación.
  let hudOn = false;
  let locOn = true;
  function sendVisible() {
    send({ t: 'visible', v: hudOn, loc: hudOn && locOn });
  }

  function applyCategory() {
    Object.keys(sent).forEach((k) => delete sent[k]);
    if (sim.category === 'bicycle') {
      hudOn = false;
      sendVisible();
      return;
    }
    const p = profile();
    sim.speed = 0;
    sim.gear = 1;
    sim.msl = p.aircraft ? 120 : 0;
    sim.agl = p.aircraft ? 2 : 0;
    send({ t: 'profile', profile: p });
    hudOn = true;
    sendVisible();
    slow(true);
  }

  // Misma fórmula que client/telemetry.lua (frontend.xml, alineado L/B en la zona segura).
  function minimapRect() {
    const inset = (1 - safe) / 2;
    const scaleX = (16 / 9) / (res[0] / res[1]);
    const l = inset - 0.0045;
    return { l: Math.max(0, l), r: l + 0.150 * scaleX, t: 1 - inset + 0.002 - 0.188888, b: 1 - inset + 0.002 };
  }

  function sendSafe() {
    const mm = minimapRect();
    Object.assign(map.style, {
      left: `${mm.l * res[0]}px`, top: `${mm.t * res[1]}px`,
      width: `${(mm.r - mm.l) * res[0]}px`, height: `${(mm.b - mm.t) * res[1]}px`,
    });
    send({ t: 'safe', safe, mm, gap: 12 });
  }

  let zoom = 'fit';
  function fit() {
    const [w, h] = res;
    const stage = q('[data-stage]');
    const k = zoom === 'fit' ? Math.min((stage.clientWidth - 48) / w, (stage.clientHeight - 80) / h, 1) : Number(zoom);
    stage.classList.toggle('is-zoomed', zoom !== 'fit');
    if (zoom !== 'fit') requestAnimationFrame(() => { stage.scrollLeft = stage.scrollWidth; stage.scrollTop = stage.scrollHeight; });
    Object.assign(screen.style, { width: `${w}px`, height: `${h}px`, transform: `scale(${k})`, marginRight: `${w * k - w}px`, marginBottom: `${h * k - h}px` });
    Object.assign(hud.style, { width: `${w}px`, height: `${h}px` });
    q('[data-meta]').textContent = `${w} × ${h} · mostrado al ${Math.round(k * 100)} % · zona segura ${Math.round(safe * 100)} %`;
    sendSafe();
  }

  // ── Escenarios: generan la entrada del pedal, no la velocidad.
  function pedalInput() {
    const t = sim.t;
    switch (sim.scenario) {
      case 'max': return 1;
      case 'idle': return 0;
      case 'coast': return 0;
      case 'manual': return sim.manualPedal;
      case 'reverse': return 0.45;
      default: {
        const phase = t % 16;
        if (phase < 6) return 0.55 + 0.4 * Math.sin(phase * 0.9) ** 2;
        if (phase < 10) return 0.3;
        if (phase < 12) return 0;
        return 0.75;
      }
    }
  }

  function brakeInput() {
    if (sim.scenario === 'idle') return 1;
    if (sim.scenario === 'drive') {
      const phase = sim.t % 16;
      return phase >= 10 && phase < 12 ? 0.8 : 0;
    }
    return 0;
  }

  function physics(dt) {
    const p = profile();
    if (!p) return;
    sim.t += dt;
    let pedal = sim.engineOn && !sim.destroyed ? pedalInput() : 0;
    if (sim.cruise && pedal < 0.1 && sim.category !== 'plane' && sim.category !== 'heli') {
      pedal = Math.max(0, Math.min(1, 0.25 + (sim.cruiseTarget - sim.speed) * 0.35));
    }
    const fuelEmpty = sim.fuelMode === 'empty';
    if (fuelEmpty) pedal = 0;
    sim.pedal = pedal;
    const brake = brakeInput();
    sim.reverse = sim.scenario === 'reverse' && p.gear;
    const nitro = sim.nitroOn && sim.nitroMode === 'equipped' && sim.nitroAmt > 0 ? 1.6 : 1;

    if (p.aircraft) {
      const top = p.aircraft === 'plane' ? 118 : 62;
      sim.speed += ((pedal * top) - sim.speed) * dt * 0.35;
      const climb = p.aircraft === 'plane' ? (sim.speed > 40 ? (pedal - 0.4) * 18 : -2) : (pedal - 0.45) * 9;
      sim.vs += (climb - sim.vs) * dt * 1.5;
      sim.agl = Math.max(0, sim.agl + sim.vs * dt);
      if (sim.agl === 0 && sim.vs < 0) sim.vs = 0;
      sim.msl = 38 + sim.agl + Math.sin(sim.t * 0.2) * 6;
      sim.rpm = 0;
      return;
    }

    if (!p.gear) {
      const top = 30;
      sim.rpm += ((sim.engineOn ? 0.2 + pedal * 0.8 : 0) - sim.rpm) * dt * 3;
      sim.speed += (pedal * top - sim.speed) * dt * (pedal > sim.speed / top ? 0.4 : 0.25);
      sim.speed = Math.max(0, sim.speed - brake * 6 * dt);
      return;
    }

    if (sim.reverse) {
      sim.gear = 0;
      sim.speed += (pedal * 9 - sim.speed) * dt * 0.8;
    } else {
      if (sim.gear === 0) sim.gear = 1;
      const ratio = RATIOS[sim.gear];
      const force = pedal * 14 * Math.sqrt(ratio / 3.4) * nitro;
      const drag = 0.0016 * sim.speed * sim.speed + (sim.speed > 0.1 ? 0.15 : 0);
      sim.speed = Math.max(0, sim.speed + (force - drag - brake * 8) * dt);
    }
    const ratio = RATIOS[sim.gear];
    const k = sim.category === 'motorcycle' ? 60 : 72;
    let rpm = sim.engineOn && !sim.destroyed ? 0.2 + (sim.speed * ratio) / k : 0;
    if (sim.engineOn && pedal > 0 && sim.speed < 2) rpm = Math.max(rpm, 0.2 + pedal * 0.35);
    sim.rpm = Math.min(1, rpm);
    if (!sim.reverse && sim.rpm > 0.92 && sim.gear < 6) sim.gear += 1;
    else if (!sim.reverse && sim.rpm < 0.42 && sim.gear > 1) sim.gear -= 1;
    if (nitro > 1) sim.nitroAmt = Math.max(0, sim.nitroAmt - 12.5 * dt);
  }

  function fast() {
    const p = profile();
    if (!p || !ready) return;
    const msg = { t: 'f' };
    let changed = false;
    const put = (key, value, eps) => {
      if (sent[key] === undefined || (eps ? Math.abs(sent[key] - value) > eps : sent[key] !== value)) {
        sent[key] = value;
        msg[key] = value;
        changed = true;
      }
    };
    put('s', +sim.speed.toFixed(2), 0.05);
    put('p', +sim.pedal.toFixed(3), 0.01);
    if (p.rpm) put('r', +sim.rpm.toFixed(3), 0.005);
    if (p.gear) put('g', sim.gear);
    if (p.aircraft) {
      if (p.aircraft === 'plane') put('m', Math.round(sim.msl), 0.5);
      put('a', Math.round(sim.agl), 0.5);
      if (p.aircraft === 'heli') put('v', +sim.vs.toFixed(2), 0.05);
    }
    if (changed) send(msg);
  }

  function slow(force) {
    const p = profile();
    if (!p || !ready) return;
    const warn = sim.warnings;
    let fuel = warn ? 9 : 68;
    if (sim.fuelMode === 'empty') fuel = 0;
    else if (sim.fuelMode === 'nodata') fuel = null;
    const eng = sim.destroyed ? 0 : warn ? 24 : sim.eng;
    const moving = sim.speed * 3.6 > 20;
    const tt = {
      belt: sim.belt ? 'on' : moving ? 'warn' : 'off',
      lights: sim.lights,
      ind: sim.ind,
      cruise: sim.cruise ? sim.cruiseTarget : 0,
    };
    const nos = p.nitro && sim.nitroMode !== 'none' ? { amt: sim.nitroMode === 'empty' ? 0 : Math.round(sim.nitroAmt), cap: 100, on: sim.nitroOn && sim.nitroMode === 'equipped' && sim.nitroAmt > 0 } : false;
    const msg = {
      t: 's', fuel, eng, run: sim.engineOn && !sim.destroyed,
      nos, beltWarn: p.telltales.belt && !sim.belt && moving, tt,
    };
    const key = JSON.stringify(msg);
    if (force || key !== sent.slow) {
      sent.slow = key;
      send(msg);
    }
  }

  // ── Controles
  document.querySelectorAll('[data-group]').forEach((group) => {
    group.addEventListener('click', (e) => {
      const b = e.target.closest('button');
      if (!b) return;
      group.querySelectorAll('button').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
      const name = group.dataset.group;
      if (name === 'category') { sim.category = b.dataset.value; sim.cruise = false; applyCategory(); }
      if (name === 'scenario') sim.scenario = b.dataset.value;
      if (name === 'res') { res = b.dataset.value.split('x').map(Number); fit(); }
      if (name === 'zoom') { zoom = b.dataset.value; fit(); }
      if (name === 'scene') screen.dataset.scene = b.dataset.value;
      if (name === 'place') sendPlace(b.dataset.value);
    });
  });

  document.querySelectorAll('[data-toggle]').forEach((b) => {
    b.addEventListener('click', () => {
      const key = b.dataset.toggle;
      sim[key] = !sim[key];
      if (key === 'cruise') {
        if (sim.cruise && sim.speed * 3.6 < 30) {
          sim.cruise = false;
          send({ t: 'notice', key: 'notice.cruiseMin', vars: { speed: 30 / 3.6 } });
        } else if (sim.cruise) {
          sim.cruiseTarget = sim.speed;
          send({ t: 'notice', key: 'notice.cruiseOn', vars: { speed: sim.speed } });
        } else send({ t: 'notice', key: 'notice.cruiseOff' });
      }
      if (key === 'belt') send({ t: 'sound', name: sim.belt ? 'belt_on' : 'belt_off' });
      b.setAttribute('aria-pressed', String(sim[key]));
      slow(true);
    });
  });

  const cycles = {
    lights: { values: ['off', 'low', 'high'], label: { off: 'Luces: apagadas', low: 'Luces: cortas', high: 'Luces: largas' } },
    ind: { values: [0, 1, 2, 3], label: { 0: 'Intermitente: no', 1: 'Intermitente: izquierdo', 2: 'Intermitente: derecho', 3: 'Intermitente: emergencia' } },
    nitro: { values: ['equipped', 'empty', 'none'], label: { equipped: 'Nitro: equipado', empty: 'Nitro: agotado', none: 'Nitro: sin equipar' } },
    fuel: { values: ['provider', 'empty', 'nodata'], label: { provider: 'Combustible: proveedor', empty: 'Combustible: vacío (0)', nodata: 'Combustible: sin dato' } },
  };
  const cycleKey = { lights: 'lights', ind: 'ind', nitro: 'nitroMode', fuel: 'fuelMode' };
  document.querySelectorAll('[data-cycle]').forEach((b) => {
    b.addEventListener('click', () => {
      const c = cycles[b.dataset.cycle];
      const key = cycleKey[b.dataset.cycle];
      sim[key] = c.values[(c.values.indexOf(sim[key]) + 1) % c.values.length];
      if (key === 'nitroMode' && sim[key] === 'equipped') sim.nitroAmt = 74;
      b.textContent = c.label[sim[key]];
      slow(true);
    });
  });

  q('[data-engine-health]').addEventListener('input', (e) => { sim.eng = Number(e.target.value); slow(true); });
  q('[data-pedal]').addEventListener('input', (e) => (sim.manualPedal = Number(e.target.value) / 100));
  q('[data-safe]').addEventListener('input', (e) => { safe = Number(e.target.value) / 100; fit(); });
  q('[data-action="settings"]').addEventListener('click', () => send({ t: 'openSettings' }));
  // Administración: el esquema y los predeterminados salen del Lua real (dev/dump_admin.lua).
  let adminValues = null;
  q('[data-action="admin"]').addEventListener('click', async () => {
    const fixture = await fetch('admin-fixture.json').then((r) => r.json());
    adminValues = adminValues || JSON.parse(JSON.stringify(fixture.defaults));
    send({ t: 'adminOpen', fields: fixture.fields, keys: fixture.keys, defaults: fixture.defaults, values: adminValues });
  });
  window.addEventListener('message', (e) => {
    if (e.data && e.data.fcPost === 'adminSave') {
      adminValues = e.data.data.values; // la vista previa no valida: eso lo hace el servidor real
      send({ t: 'adminResult', result: { ok: true, values: adminValues, changed: 1 } });
    }
  });
  q('[data-action="units"]').addEventListener('click', () => {
    const next = { ...(settings || {}), unit: settings && settings.unit === 'mph' ? 'kmh' : 'mph' };
    settings = next;
    send({ t: 'settings', settings: next });
  });
  q('[data-action="reset-prefs"]').addEventListener('click', () => {
    settings = null;
    try { localStorage.removeItem(prefsKey); } catch (err) { /* sin almacenamiento */ }
    send({ t: 'settings', settings: {} });
  });

  // Ubicación de ejemplo (en el juego la leen client/location.lua con natives).
  const PLACES = {
    city: ['Vinewood Blvd', 'Downtown Vinewood'],
    highway: ['Great Ocean Hwy', 'Chumash'],
    sea: ['Pacific Ocean', ''],
    long: ['Calle Extremadamente Larga de Prueba del Distrito Norte', 'Barrio con un Nombre Muy Largo para Comprobar Recortes'],
  };
  let bearing = 30;
  function sendPlace(kind) {
    if (kind === 'hidden') { locOn = false; sendVisible(); map.style.visibility = 'hidden'; return; }
    map.style.visibility = '';
    const [main, sub] = PLACES[kind];
    send({ t: 'location', main, sub });
    if (!locOn) { locOn = true; sendVisible(); }
  }
  setInterval(() => {
    bearing = (bearing + 7) % 360;
    send({ t: 'location', bearing, sector: Math.floor((bearing + 22.5) / 45) % 8 });
  }, 600);

  window.addEventListener('resize', fit);
  hud.addEventListener('load', fit);
  fit();

  let last = performance.now();
  let slowAcc = 0;
  setInterval(() => {
    const now = performance.now();
    const dt = Math.min((now - last) / 1000, 0.2);
    last = now;
    physics(dt);
    fast();
    slowAcc += dt;
    if (slowAcc >= 0.25) { slowAcc = 0; slow(); }
  }, 50);

  window.FCPreview = { sim, send, applyCategory, slow };
})();
