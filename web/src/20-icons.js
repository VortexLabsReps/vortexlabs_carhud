// Iconos empaquetados en línea (sin CDN). Combustible, motor, nitro,
// crucero y flechas derivan de Lucide (licencia ISC, ver THIRD_PARTY.md).
// Cinturón y faro son pictogramas propios basados en la referencia aprobada.
const stroke = (body, extra) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"${extra || ''}>${body}</svg>`;

FC.icons = {
  fuel: stroke('<line x1="3" x2="15" y1="22" y2="22"/><line x1="4" x2="14" y1="9" y2="9"/><path d="M14 22V4a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v18"/><path d="M14 13h2a2 2 0 0 1 2 2v2a2 2 0 0 0 2 2a2 2 0 0 0 2-2V9.83a2 2 0 0 0-.59-1.42L18 5"/>'),
  engine: stroke('<path d="M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z"/><path d="M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"/><path d="M12 2v2"/><path d="M12 22v-2"/><path d="m17 20.66-1-1.73"/><path d="M11 10.27 7 3.34"/><path d="m20.66 17-1.73-1"/><path d="m3.34 7 1.73 1"/><path d="M14 12h8"/><path d="M2 12h2"/><path d="m20.66 7-1.73 1"/><path d="m3.34 17 1.73-1"/><path d="m17 3.34-1 1.73"/><path d="m11 13.73-4 6.93"/>'),
  nitro: stroke('<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>'),
  cruise: stroke('<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>'),
  left: stroke('<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>', ' stroke-width="2"'),
  right: stroke('<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>', ' stroke-width="2"'),
  close: stroke('<path d="M18 6 6 18"/><path d="m6 6 12 12"/>', ' stroke-width="2"'),
  navigation: stroke('<polygon points="12 2 19 21 12 17 5 21 12 2"/>', ' stroke-width="1.8"'),
  chevron: '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M5 1.2 9 7.6H1Z" fill="currentColor"/></svg>',
  // Persona con cinturón: cabeza, torso, banda diagonal y banda abdominal.
  belt:
    '<svg viewBox="0 0 18 18" aria-hidden="true"><circle cx="9" cy="2.2" r="2.05" fill="currentColor"/>' +
    '<path d="M4.8 17.2V10.6a4.2 4.2 0 0 1 8.4 0v6.6Z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>' +
    '<path d="M3.3 15.6 14.9 5.9" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>' +
    '<path d="M3.2 14.3h11.6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
  // Faro: haces inclinados (cortas), horizontales (largas) o tachado (apagadas).
  headlamp:
    '<svg viewBox="0 0 18 18" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' +
    '<path d="M10.2 3.2h1.9a4.9 5.8 0 0 1 0 11.6h-1.9Z"/>' +
    '<g class="fc-beam-low"><path d="M7.6 4.4 1.4 6.9"/><path d="M7.6 8.6 1.4 11.1"/><path d="M7.6 12.8 1.4 15.3"/></g>' +
    '<g class="fc-beam-high"><path d="M7.6 4.6H1.2"/><path d="M7.6 9H1.2"/><path d="M7.6 13.4H1.2"/></g>' +
    '<g class="fc-lamp-off"><path d="M1.6 16.4 16.4 1.6"/></g></svg>',
};

FC.mountIcons = (root) => {
  root.querySelectorAll('[data-icon]').forEach((el) => {
    el.innerHTML = FC.icons[el.dataset.icon] || '';
  });
  root.querySelectorAll('[data-tt]').forEach((el) => {
    const key = el.dataset.tt;
    el.innerHTML = key === 'belt' ? FC.icons.belt : key === 'lights' ? FC.icons.headlamp : FC.icons[key] || '';
  });
  root.querySelectorAll('[data-turn]').forEach((el) => {
    el.innerHTML = FC.icons[el.dataset.turn] || '';
  });
  root.querySelectorAll('[data-vs-arrow]').forEach((el) => {
    el.innerHTML = FC.icons.chevron;
  });
  root.querySelectorAll('[data-action="close"].fc-icon-btn, [data-admin-action="cancel"].fc-icon-btn').forEach((el) => {
    el.innerHTML = FC.icons.close;
  });
};
