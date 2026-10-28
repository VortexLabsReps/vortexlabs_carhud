# Relación de pruebas · vortexlabs_carhud 1.0.0

Documento interno de desarrollo (no se incluye en el ZIP de instalación). Cada prueba indica su **tipo**. Nada de lo estático o simulado sustituye a una prueba dentro de FiveM.

| Tipo | Qué es |
|---|---|
| **Estática** | Análisis del código sin ejecutarlo |
| **Simulación Lua** | Lua 5.3 (fengari) con natives simuladas en `dev/fivem.lua`; sin física real de GTA |
| **Simulación NUI** | La interfaz real (`html/`) en Chrome, con mensajes como los de Lua |
| **En el juego** | Dentro de FiveM, con un cliente conectado |

## 1. Estáticas · `node dev/check.js` · todo correcto

- Sintaxis de todo el Lua (cliente, servidor, compartido, config) y del JS.
- Cada native usada existe, está en el lado correcto (cliente o servidor) y tiene el número de argumentos correcto, según la base oficial de natives de FiveM.
- Ningún uso de `os` ni `io` en el código de cliente o compartido.

## 2. Simulación Lua · `cd dev && npm test` · 510/510

| Suite | Resultado | Cubre |
|---|---|---|
| `test_shared.lua` | 129/129 | Categorías y matriz de funciones; escala; pedal; salud del motor (−4000…1000); escala del HUD; detector vectorial de choques; ajustes del jugador; contabilidad del nitro; **idiomas** (inglés por defecto, español, clave ausente → inglés, idioma inexistente → inglés, mismas claves en EN y ES) |
| `test_client.lua` | 168/168 | Arranque dentro del vehículo; visibilidad; cinturón propio; expulsión; **luces e intermitentes**; crucero; motor y llaves; turbo ausente; nitro (cliente); proveedores de combustible; avisos y vehículo destruido; **bicicleta: exclusión total**; **moto, lancha, avión y helicóptero**; cinturón externo; frameworks; ajustes del jugador; **parada del recurso dentro del vehículo** (luces devueltas, cinturón y bloqueo restablecidos, foco liberado) |
| `test_server.lua` | 45/45 | Nitro: instalar, activar, consumir, **agotar**, condiciones de parada, categorías incompatibles, comando, permisos por framework, persistencia |
| `test_admin.lua` | 42/42 | Esquema y validación, permisos en el servidor, diagnóstico, guardado atómico, restaurar predeterminados, límite de frecuencia |
| `test_admin_persist.lua` | 7/7 | Reinicio con `data/admin.json` |
| `test_admin_client.lua` | 35/35 | Ajustes del servidor al arrancar, cambios en caliente, umbral y fuerza, categorías y modelos, aviso y bloqueo, menú |
| `test_crash_client.lua` | 29/29 | **Sin cinturón: impactos frontal, trasero, lateral y diagonal**, marcha atrás y golpes recibidos; **con cinturón ninguno expulsa**; sin falsos positivos (frenadas, curvas, saltos, teletransportes); diagnóstico |
| `test_location.lua` | 55/55 | Rumbo e histéresis; calle y zona; **visibilidad compartida con el HUD en un solo mensaje**; a pie oculto; 10 entradas y salidas seguidas; pausa; minimapa oculto; **posición predeterminada** y preferencias |

## 3. Simulación NUI · `dev/nui_test.html` · 141/141

Se ejecutó en Chrome headless en tiempo real (pintando fotogramas) y con los textos reales de `locales/es.json`.

- **Interfaz:** distribución del conjunto; testigos e **intermitentes**; **anillo de nitro** (sin instalar oculto, disponible, activo, agotado); escala y opacidad; **color gradual del motor y reparación gradual**; tamaño 80–150 %; ajustes; aeronaves; menú de administración (restricciones, errores, permisos).
- **Ubicación:** misma anchura y bordes que el minimapa; 12 px por encima sin solaparlo; nombres largos recortados.
- **Sincronización:** una sola capa y una sola transición para todo el HUD; 12 entradas y salidas seguidas; **40 fotogramas reales** con la misma opacidad y visibilidad en cada uno.
- **Posiciones y preferencias:** posición predeterminada del servidor; «Posición original» y «Restablecer tamaño» vuelven a ella sin borrar el resto de preferencias.

**Vista previa** (`preview/`), también en simulación NUI:
- 6 resoluciones (1080p, 1440p, 4K, 21:9, 32:9, 5:4) × 4 zonas seguras: ubicación alineada con el minimapa (desviación ≤ 0,03 px) y velocímetro dentro de la zona segura.
- Menús de jugador y administración en **inglés y español**, a 1920×1080 y 1280×1024: sin desbordamientos y sin claves sin traducir.

### Identidad VortexLabs (simulación NUI)

- Arco del velocímetro neutro a velocidad media y coral solo en el último tramo cerca del máximo (2 pruebas nuevas); anillo de nitro neutro al 74 %.
- Color del motor: blanco neutro sano, cálido con el daño y coral en avería; reparación gradual.
- Menús de jugador y administración en español e inglés a **1280×720, 1920×1080 y 2560×1080**: sin desbordamientos, sin claves sin traducir, paneles dentro de pantalla y **contraste WCAG ≥ 4,5:1** (≥ 3:1 en texto grande) en todo el texto, medido sobre el color real de cada elemento y su fondo.
- Foco con teclado (Tab real): anillo coral de 2 px con 2 px de separación.
- Consola sin errores del recurso. Los 404 de `outfit-*.woff2` que aparecieron venían de una hoja de estilos antigua en caché; el `html/app.css` generado ya no referencia ninguna fuente web.

## 4. En el juego (FiveM, servidor de pruebas Qbox + ox_fuel)

Comprobado en el log del cliente (`CitizenFX_log`) de la sesión de desarrollo:

- **Arranque y reinicios repetidos** del recurso sin errores de script. El único error registrado, el uso de `os` en el cliente, se corrigió al principio del desarrollo y no ha vuelto a aparecer.
- **Decisiones reales de choque** con `/carhudcrash`: impactos descartados por llevar el cinturón (`belted`), descartados por relación (`ratio`) y expulsiones (`impact`).
- **Menú del jugador:** posición de la ubicación movida y guardada; `/carhud layout` imprime los valores (se usaron como predeterminados).

## 5. Pendiente dentro del juego antes de publicar

Requieren un cliente conectado; no se pueden hacer desde las herramientas de desarrollo. Se recomienda tener `resmon 1` abierto.

| # | Prueba |
|---|---|
| 1 | Instalación limpia desde el ZIP en un servidor sin `data/` previo: el HUD aparece en inglés, con la posición predeterminada y sin errores |
| 2 | Entrar y salir varias veces (también rápido): velocímetro, nitro, fila inferior y ubicación aparecen y desaparecen juntos; pausa; a pie; bicicleta |
| 3 | Coche, moto, lancha, avión y helicóptero: perfil correcto |
| 4 | Luces cortas y largas, intermitentes y emergencia |
| 5 | Expulsión sin cinturón: frontal, trasera (marcha atrás), lateral y diagonal; con cinturón, ninguna |
| 6 | Daño progresivo del motor y reparación (color gradual) |
| 7 | Nitro: instalar, usar, agotar y retirar |
| 8 | `/carhudadmin`: cambiar valores, guardar, reiniciar el recurso y comprobar que se conservan; jugador sin permiso rechazado |
| 9 | `restart vortexlabs_carhud` a pie y dentro de un vehículo; `stop vortexlabs_carhud` dentro del vehículo: sin foco, sin controles bloqueados, luces devueltas |
| 10 | `Config.Locale = 'es'`: textos en español en menús y avisos |
| 11 | ESX, QBCore, LegacyFuel y cdn-fuel en un servidor real (solo simulados hasta ahora) |
| 12 | Otra resolución y otra zona segura del juego |
| 13 | Identidad VortexLabs en el CEF de FiveM: Bahnschrift y Segoe UI cargan (fuentes de Windows), el logotipo se ve en `/carhudadmin`, legibilidad del HUD de día y de noche y sobre asfalto claro |

No se publican cifras de rendimiento: `/carhud perf` y `resmon 1` permiten medirlo en cada servidor.
