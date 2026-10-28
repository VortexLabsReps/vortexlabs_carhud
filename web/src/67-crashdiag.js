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
