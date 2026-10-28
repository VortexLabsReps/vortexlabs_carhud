// Textos de la interfaz. La única fuente es locales/<idioma>.json (sección "ui"):
// Lua los envía en el mensaje 'init' junto con el inglés como respaldo.
FC.i18n = { strings: {}, fallback: {} };
FC.lang = 'en';

FC.setLocale = (lang, strings, fallback) => {
  FC.lang = typeof lang === 'string' ? lang : 'en';
  FC.i18n.strings = strings && typeof strings === 'object' ? strings : {};
  FC.i18n.fallback = fallback && typeof fallback === 'object' ? fallback : {};
};

FC.t = (key, vars) => {
  const { strings, fallback } = FC.i18n;
  let text = strings[key] != null ? strings[key] : fallback[key] != null ? fallback[key] : key;
  if (vars) text = text.replace(/\{(\w+)\}/g, (_, k) => (vars[k] != null ? vars[k] : ''));
  return text;
};

FC.applyI18n = (root) => {
  root.querySelectorAll('[data-i18n]').forEach((el) => FC.setText(el, FC.t(el.dataset.i18n)));
  root.querySelectorAll('[data-i18n-label]').forEach((el) => {
    el.setAttribute('aria-label', FC.t(el.dataset.i18nLabel));
    el.setAttribute('title', FC.t(el.dataset.i18nLabel));
  });
  document.documentElement.lang = FC.lang;
};
