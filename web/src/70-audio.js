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
