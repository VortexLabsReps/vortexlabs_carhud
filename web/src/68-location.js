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
