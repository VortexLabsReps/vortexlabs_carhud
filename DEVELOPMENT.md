# Desarrollo de vortexlabs_carhud

Documento interno. Nada de esto se incluye en el ZIP de instalación (`tools/package.js` solo copia lo que necesita el servidor).

## Estructura

```
fxmanifest.lua, config.lua      recurso
client/ server/ shared/ bridge/ código Lua
locales/en.json, es.json        todos los textos (game = Lua, ui = interfaz)
data/                           admin.json y nitro.json (estado del servidor; el ZIP los lleva vacíos)
html/                           interfaz compilada que carga FiveM (generada desde web/)
web/                            fuentes de la interfaz (JS por módulos y CSS)
preview/                        vista previa con datos simulados (no se carga en FiveM)
tools/                          build.js · package.js · preview.js · gen-sounds.js
dev/                            pruebas: check.js, simulador Lua (fivem.lua), suites test_*.lua, nui_test.html
dist/                           ZIP generados
```

## Tareas

- **Compilar la interfaz** tras editar `web/`: `node tools/build.js` (genera `html/app.js`, `html/app.css` y `html/index.html`).
- **Vista previa:** `node tools/preview.js` y abre `http://localhost:5179/preview/`. Con `?lang=es` se ve en español.
- **Pruebas** (en `dev/`, tras `npm install` una vez):
  - `node check.js`: estática.
  - `npm test`: simulaciones Lua.
  - `http://localhost:5179/dev/nui_test.html`: interfaz.
  - Las pruebas de fotogramas necesitan una página que pinte. En un panel oculto se marcan como «omit»; en ese caso, ejecútalas en Chrome headless en tiempo real (`--remote-debugging-port`).
- **Empaquetar:** `node tools/package.js` genera `dist/vortexlabs_carhud-v<versión>.zip` con una sola carpeta `vortexlabs_carhud/`.

## Textos

- Añade cada texto nuevo a **los dos** archivos de `locales/`. La prueba de idiomas de `test_shared.lua` falla si falta una clave.
- En Lua, usa `CarHud.T('clave', ...)`, con formato `string.format`.
- En la interfaz, usa `FC.t('clave', { var })`, con marcadores `{var}`.

## Calibrar la posición predeterminada

1. En el juego, coloca el HUD con `/carhud` → **Mover HUD**.
2. Ejecuta `/carhud layout`.
3. Copia `x`, `y` y `scale` de la ubicación en `Config.Location.default`.
