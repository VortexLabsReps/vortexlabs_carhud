# Changelog

## 1.0.0 — first public release

First public release of VortexLabs Car HUD.

**Design**
- VortexLabs visual identity: black and charcoal surfaces, neutral greys, coral (`#FE3555`) only for attention, main actions, selection and focus; 30° geometry details; system fonts (Bahnschrift / Segoe UI), no bundled web fonts.

**HUD**
- Bottom-right speedometer with a segmented arc, gear, unit and RPM.
- Nitro ring, side indicators, throttle bar and status row (seatbelt, lights, cruise, fuel, engine; altitude on aircraft).
- Profiles for cars, motorcycles (compact), boats, planes and helicopters. Never shown on foot or on bicycles.
- Engine health colour that changes gradually with damage and recovers after a repair, plus a separate "Engine damaged" warning.
- Location bar above the minimap (street, area and heading), anchored to the real minimap at any resolution and safe zone.
- One shared visibility state and fade for the speedometer, nitro, status row and location.

**Driving features**
- Seatbelt with sounds, unbuckled warning and exit lock.
- Crash ejection from the velocity vector (frontal, rear, side and diagonal), with collision evidence required and separate threshold and force settings.
- Support for an external seatbelt (`qbx_seatbelt`).
- Own lights, high beams, indicators and hazards.
- Cruise control.
- Engine start/stop with key checks.
- Server-validated nitro, saved per plate.

**Integration**
- Standalone, ESX, QBCore and Qbox, detected automatically.
- Read-only fuel from `ox_fuel`, `LegacyFuel`, `cdn-fuel` or the native level.
- Client exports, server nitro exports and a `vortexlabs_carhud:notify` event.

**Menus and settings**
- Player menu `/carhud`: units, colour, modules, values, volume, size, position, opacity and location. Preferences are saved per player and limited by the server.
- Admin menu `/carhudadmin`: ACE and framework-group permissions checked on the server, values validated on the server and saved to `data/admin.json`, with section defaults.
- English and Spanish (`locales/*.json`), English by default, with English fallback for missing texts.

**Fixes made during the pre-release review**
- All visible texts moved to the locale files, including the location's compass points and the console messages.
- Repeated error messages are rate-limited.
- Unused functions removed.

---

## 1.0.0 — primera versión pública (resumen en español)

Primera versión pública de VortexLabs Car HUD.

- **Diseño:** identidad visual VortexLabs: negro y carbón, grises neutros y coral (`#FE3555`) solo para lo que pide atención, la acción principal, la selección y el foco; detalles geométricos a 30°; fuentes del sistema (Bahnschrift / Segoe UI), sin fuentes web incluidas.

- **HUD:**
  - Velocímetro abajo a la derecha, con anillo de nitro, intermitentes laterales, acelerador y fila de estado.
  - Perfiles para coche, moto, embarcación, avión y helicóptero. Nunca se muestra a pie ni en bicicleta.
  - Color del motor gradual con el daño.
  - Barra de ubicación sobre el minimapa.
  - Visibilidad y fundido compartidos por todos los componentes.
- **Funciones de conducción:**
  - Cinturón con aviso y bloqueo de salida.
  - Expulsión por vector de velocidad (frontal, trasera, lateral y diagonal), con evidencia de colisión.
  - Cinturón externo (`qbx_seatbelt`).
  - Luces, largas, intermitentes y emergencia.
  - Control de crucero.
  - Motor con comprobación de llaves.
  - Nitro validado por el servidor y guardado por matrícula.
- **Integración:**
  - Standalone, ESX, QBCore y Qbox, detectados automáticamente.
  - Combustible de solo lectura (`ox_fuel`, `LegacyFuel`, `cdn-fuel` o nativo).
  - Exports de cliente y de nitro, y evento `vortexlabs_carhud:notify`.
- **Menús:**
  - `/carhud` con preferencias por jugador dentro de los límites del servidor.
  - `/carhudadmin` con permisos y validación en el servidor, guardado en `data/admin.json` y predeterminados por sección.
- **Idiomas:** inglés y español (`locales/*.json`), inglés por defecto y como respaldo.
- **Revisión previa a la publicación:**
  - Textos centralizados en los archivos de idioma.
  - Errores repetidos limitados.
  - Funciones sin uso eliminadas.
