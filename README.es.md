# VortexLabs Car HUD (`vortexlabs_carhud`) · v1.0.0

HUD de vehículos gratuito para FiveM, de **VortexLabs**. Muestra un único velocímetro abajo a la derecha, con anillo de nitro, intermitentes laterales, barra de acelerador y fila de estado, y una barra de ubicación encima del minimapa. Además incluye funciones de conducción propias: cinturón con expulsión en choques, luces e intermitentes, control de crucero, arranque y parada del motor, y nitro validado por el servidor.

Funciona en **standalone, ESX, QBCore y Qbox** sin dependencias obligatorias.

*English version: [README.md](README.md)*

---

## Índice

1. [Funciones](#funciones)
2. [Requisitos](#requisitos)
3. [Instalación](#instalación)
4. [Frameworks](#frameworks)
5. [Combustible](#combustible)
6. [Idioma y unidades](#idioma-y-unidades)
7. [Controles](#controles)
8. [Menú del jugador](#menú-del-jugador)
9. [Menú de administración y permisos](#menú-de-administración-y-permisos)
10. [Ajustes de las funciones](#ajustes-de-las-funciones)
11. [Categorías de vehículos](#categorías-de-vehículos)
12. [Ubicación sobre el minimapa](#ubicación-sobre-el-minimapa)
13. [Valores del servidor frente a preferencias del jugador](#valores-del-servidor-frente-a-preferencias-del-jugador)
14. [Exports, eventos e integraciones](#exports-eventos-e-integraciones)
15. [Solución de problemas](#solución-de-problemas)
16. [Limitaciones conocidas](#limitaciones-conocidas)
17. [Informar de un error](#informar-de-un-error)
18. [Créditos](#créditos)

---

## Funciones

**HUD**
- **Velocímetro:** arco segmentado con marcha, unidad y RPM (cuando el vehículo los tiene). La escala del arco se estima para cada modelo.
- **Anillo de nitro** encima del velocímetro. Solo aparece en vehículos con nitro instalado y muestra la carga restante. El centro se ilumina mientras se usa.
- **Intermitentes** a ambos lados, con el estado real del vehículo; las luces de emergencia parpadean sincronizadas.
- **Barra de acelerador** bajo el velocímetro.
- **Fila de estado:** cinturón, luces y crucero │ combustible y motor. En aeronaves se muestra la altitud.
- **Color del estado del motor:** cambia de forma gradual con el daño y vuelve de forma gradual al reparar. Por debajo del umbral configurado aparece además el aviso «Motor dañado».
- **Barra de ubicación sobre el minimapa:** calle, zona y rumbo (8 puntos cardinales). Coincide con el ancho y la posición del minimapa en cualquier resolución y zona segura.
- **Visibilidad compartida:** velocímetro, nitro, fila de estado y ubicación aparecen y desaparecen juntos, con un único fundido de 140 ms.
- Nunca se muestra a pie ni en bicicleta. Se oculta en cuanto el jugador empieza a bajar del vehículo, en el menú de pausa y cuando otro recurso oculta el HUD.
- Cada tipo de vehículo tiene su perfil: coche, moto (compacto), embarcación, avión y helicóptero.
- **Diseño VortexLabs:** superficies negras y carbón con grises neutros. Los valores en su rango normal se ven neutros; el coral aparece solo en lo que pide atención (el final del arco de velocidad, el cinturón desabrochado, el daño grave) y en la acción principal, la selección y el foco de los menús. Cada jugador puede seguir eligiendo su color de acento.

**Funciones de conducción** (cada una se puede desactivar para todo el servidor)
- **Cinturón:** tecla, sonidos, aviso al circular desabrochado y bloqueo de salida mientras está abrochado.
- **Expulsión en choques** sin cinturón: detecta impactos frontales, traseros, laterales y diagonales a partir del vector de velocidad, y exige evidencia de colisión. También funciona con un cinturón externo (`qbx_seatbelt` se detecta automáticamente).
- **Luces:** pulsar para encender, mantener para las largas. Intermitentes izquierdo y derecho, y luces de emergencia.
- **Control de crucero:** fijar, cancelar, subir y bajar. Solo en vehículos terrestres.
- **Arranque y parada del motor**, respetando las llaves (`qbx_vehiclekeys` de forma automática, o tu propia comprobación).
- **Nitro:** lo instalan los administradores o los exports de servidor. El servidor descuenta y valida la carga, y la guarda por matrícula.

**Menús**
- **Menú del jugador `/carhud`:** unidades, color principal, módulos visibles, valores numéricos, volumen, tamaño, posición y opacidad, y para la ubicación: mostrar u ocultar, tamaño y posición. Las preferencias se guardan para cada jugador.
- **Menú de administración `/carhudadmin`:** cinturón y accidentes, motor, luces, crucero y nitro. El servidor comprueba los permisos y los cambios se guardan sin base de datos.
- Interfaz en **inglés y español**.

---

## Requisitos

**Obligatorio:** solo FiveM. No hace falta base de datos, inventario ni librerías.

**Opcional, se detecta automáticamente:**

| Tipo | Compatible |
|---|---|
| Framework | Qbox (`qbx_core`), QBCore (`qb-core`), ESX (`es_extended`) o standalone |
| Combustible | `ox_fuel`, `LegacyFuel`, `cdn-fuel` o el nivel nativo |
| Cinturón | el cinturón propio, o `qbx_seatbelt` como fuente externa |
| Llaves | `qbx_vehiclekeys`, o cualquier sistema de llaves mediante una función o export |

---

## Instalación

1. Descarga `vortexlabs_carhud-v1.0.0.zip` de la página de [Releases](../../releases) y descomprímelo en tu carpeta `resources`. Debe quedar `resources/vortexlabs_carhud/fxmanifest.lua`.
   El ZIP de la release solo contiene lo que necesita el servidor. Clonar el repositorio también funciona, pero trae las carpetas de desarrollo (`web/`, `preview/`, `tools/`, `dev/`), que FiveM ignora.
2. En `server.cfg`, añádelo **después** de tu framework, tu combustible y tus llaves:

   ```cfg
   ensure vortexlabs_carhud
   ```

3. Da el permiso de administración (lo usan `/carhudadmin`, `/carhudcrash` y `/carhudnitro`):

   ```cfg
   add_ace group.admin vortexlabs_carhud.admin allow
   ```

4. Detén cualquier otro HUD de vehículos (por ejemplo `qbx_hud`, `qb-hud` o `esx_hud`); si no, se verán dos HUD a la vez.
5. Reinicia el servidor. La consola del servidor muestra lo que ha detectado, por ejemplo
   `[vortexlabs_carhud] v1.0.0 · Framework: qbox · Fuel: auto · Seatbelt: auto`.

La interfaz viene ya compilada (`html/`), así que no necesitas Node.js ni ningún paso de compilación.

**Orden de inicio.** Si `vortexlabs_carhud` arranca antes que el framework o el combustible, los detecta cuando se inician. Aun así, el orden recomendado es framework → combustible → llaves → `vortexlabs_carhud`.

**Reinicio.** `restart vortexlabs_carhud` funciona tanto a pie como dentro de un vehículo. Al detenerse, el recurso devuelve las luces al juego, restablece el cinturón y su bloqueo de salida, libera el foco de la interfaz y apaga cualquier nitro activo.

### Recursos que se solapan

| Recurso | Qué ocurre | Qué hacer |
|---|---|---|
| `qbx_hud`, `qb-hud`, `esx_hud`… | Dos HUD de vehículo | Detén el otro HUD |
| `qbx_seatbelt` | Se detecta: el HUD muestra su estado y la mecánica propia del cinturón queda desactivada | Nada. Para usar la mecánica propia, detén `qbx_seatbelt` y pon `Config.Seatbelt.mode = 'own'` |
| Otro cinturón | Dos cinturones en la misma tecla | `Config.Seatbelt.mode = 'external'` o desactiva el otro |
| `qbx_cruise` u otro crucero | Ambos usan `Y` por defecto | Desactiva uno o cambia una tecla |
| `qbx_vehiclekeys` | Tiene su propia tecla de motor | Usa una de las dos teclas; el HUD respeta sus llaves igualmente |

---

## Frameworks

`Config.Framework = 'auto'` busca **Qbox** (`qbx_core`), después **QBCore** (`qb-core`), después **ESX** (`es_extended`) y, si no hay ninguno, funciona en standalone. Qbox se comprueba primero porque también proporciona `qb-core`. También puedes fijarlo:

```lua
Config.Framework = 'auto'        -- o 'qbox' | 'qbcore' | 'esx' | 'standalone'
```

El framework solo se usa para tres cosas:
- **Esperar a que cargue el personaje:** con `Config.Hud.requirePlayerLoaded`, el HUD permanece oculto hasta que el personaje ha cargado.
- **Notificaciones:** solo con `Config.Hud.notify = 'framework'`; si no, los avisos aparecen encima del HUD.
- **Grupos de administración:** `Config.Permissions.frameworkGroups`.

Todas las llamadas al framework van protegidas. Si el framework se reinicia o se detiene, el HUD sigue funcionando en standalone.

---

## Combustible

El nivel de combustible es **solo de lectura**: este recurso nunca modifica el nivel, el consumo ni el repostaje.

```lua
Config.Fuel = {
    provider = 'auto',     -- 'auto' | 'ox_fuel' | 'LegacyFuel' | 'cdn-fuel' | 'native'
    nativeScale = 'tank',  -- modo nativo: 'tank' (litros del depósito del handling) | 'percent' (0–100)
    decor = '_FUEL_LEVEL', -- decorador de LegacyFuel / cdn-fuel
}
```

| Proveedor | Se lee de |
|---|---|
| `ox_fuel` | `Entity(vehicle).state.fuel` |
| `LegacyFuel` | `exports.LegacyFuel:GetFuel(vehicle)`, tras comprobar que existe el decorador `_FUEL_LEVEL` |
| `cdn-fuel` | `exports['cdn-fuel']:GetFuel(vehicle)`, tras comprobar el decorador |
| `native` | `GetVehicleFuelLevel` |

- `'auto'` elige el primero que esté iniciado: `ox_fuel`, después `cdn-fuel`, después `LegacyFuel` y, si no hay ninguno, el nativo.
- **El 0 es depósito vacío.** Si el proveedor aún no tiene dato, el módulo de combustible se atenúa y muestra «—» sin avisos.
- Si el proveedor se detiene, o su export falla repetidamente, el HUD pasa a la lectura nativa y vuelve al proveedor cuando se recupera.
- En los vehículos que no usan combustible, el módulo se oculta.

---

## Idioma y unidades

```lua
Config.Locale = 'en'   -- 'en' | 'es'
```

El idioma se aplica a todo el servidor: menús, avisos, descripciones de teclas y mensajes de consola. Los jugadores no pueden elegir su propio idioma.

Todos los textos están en `locales/en.json` y `locales/es.json`. Cada archivo tiene una sección `game` (Lua) y otra `ui` (interfaz). Cualquier texto que falte se muestra en inglés.

Para añadir un idioma, copia `en.json` (por ejemplo, a `fr.json`), traduce los valores (nunca las claves) y pon `Config.Locale = 'fr'`.

**Unidades.** `Config.Hud.defaultUnit = 'kmh'` (o `'mph'`) es la unidad inicial. Cada jugador puede cambiarla en `/carhud` si `Config.Player.allowUnit = true`. El arco mantiene la misma escala física en ambas unidades: 100 km/h ocupan el mismo arco que 62 mph.

---

## Controles

| Acción | Tecla por defecto | Configuración |
|---|---|---|
| Cinturón | `B` | `Config.Seatbelt.key` |
| Luces (pulsar) · largas (mantener) | `H` | `Config.Lights.key`, `longPress` |
| Intermitente izquierdo / derecho | `←` / `→` | `Config.Lights.leftKey`, `rightKey` |
| Emergencia | `↓` | `Config.Lights.hazardKey` |
| Crucero: fijar/cancelar · subir · bajar | `Y` · `RePág` · `AvPág` | `Config.Cruise.key`, `upKey`, `downKey` |
| Motor | `G` | `Config.Engine.key` |
| Nitro (mantener) | `Mayús izq.` | `Config.Nitro.key` |
| Abrir ajustes | ninguna (`/carhud`) | `Config.Player.settingsKey` |

**Reasignar teclas.** Los jugadores cambian las teclas en **Ajustes de GTA → Asignación de teclas → FiveM**. Las teclas de la configuración, o del menú de administración, son solo *predeterminadas*: FiveM nunca sobrescribe una tecla que el jugador ya haya personalizado, y una nueva tecla predeterminada llega a cada jugador la próxima vez que se conecta. Solo se registran las teclas de las funciones activas.

| Comando | Quién | Qué hace |
|---|---|---|
| `/carhud` | todos | Abre el menú del jugador |
| `/carhud layout` | todos | Imprime en F8 tu posición y tamaño guardados (ver [Ubicación](#ubicación-sobre-el-minimapa)) |
| `/carhud perf [segundos]` | todos | Mide el coste del recurso en Lua y en la interfaz y lo imprime en F8 |
| `/carhudadmin` | admins | Abre el menú de administración |
| `/carhudcrash` | admins | Activa o desactiva el diagnóstico de expulsión (desactivado por defecto) |
| `/carhudnitro equip [capacidad]` · `refill [cantidad]` · `remove` · `info` | admins | Nitro del vehículo en el que estás |
| `carhudnitro <acción> <idJugador> [valor]` | consola del servidor | Lo mismo, para el vehículo de un jugador |

---

## Menú del jugador

`/carhud` abre el menú del jugador. Es la única parte del HUD que toma el foco del ratón. `Esc`, **Listo** o abrir el menú de pausa lo cierran y liberan el foco.

- **Unidades:** km/h o mph.
- **Color principal:** muestras o código hexadecimal.
- **Módulos visibles:** RPM, acelerador, combustible, motor, nitro, testigos, altitud y avisos.
- **Mostrar valores numéricos:** pequeños porcentajes de combustible, motor y nitro (desactivado por defecto).
- **Volumen de sonidos**, con botón de prueba.
- **Posición, escala y opacidad:**
  - Tamaño del velocímetro del 80 % al 150 %, con **Restablecer tamaño**.
  - Opacidad.
  - **Mover HUD** permite arrastrar el velocímetro y la barra de ubicación. Ambos quedan siempre dentro de la zona segura.
  - **Posición original** devuelve los dos a la posición predeterminada del servidor y conserva el resto de preferencias.
- **Ubicación:** mostrar u ocultar, y su propio tamaño. Su ancho coincide siempre con el del minimapa. **Restablecer tamaño** vuelve al predeterminado del servidor.
- **Restaurar todo** devuelve todas las preferencias a los valores del servidor.

Lo que pueden cambiar los jugadores está limitado por `Config.Player`:

```lua
Config.Player = {
    allowUnit = true, allowColor = true, allowLayout = true, allowModules = true,
    scaleMin = 0.8, scaleMax = 1.5,   -- rango de tamaño (80–150 %)
    opacityMin = 0.4,
    maxVolume = 1.0, defaultVolume = 0.6,
    settingsKey = '',                 -- tecla opcional para abrir el menú
    command = 'carhud',
}
```

Cada valor se comprueba al cargarlo y al guardarlo. Los valores no válidos se descartan, y los jugadores nunca pueden superar estos límites ni activar una función que el servidor haya desactivado.

---

## Menú de administración y permisos

`/carhudadmin` abre un menú separado del menú del jugador, con cinco secciones: **Cinturón y accidentes**, **Motor**, **Luces**, **Crucero** y **Nitro**.

**Permisos.** Un jugador es administrador si tiene el permiso ACE **o** pertenece a uno de los grupos del framework:

```lua
Config.Permissions = {
    ace = 'vortexlabs_carhud.admin',
    frameworkGroups = { 'admin', 'god', 'superadmin' },
}
```

```cfg
# server.cfg — da el permiso al grupo admin
add_ace group.admin vortexlabs_carhud.admin allow
# y añade un jugador a ese grupo (usa tu propio identificador)
add_principal identifier.license:<tu-licencia> group.admin
```

El servidor comprueba el permiso cada vez que se abre el menú y **en cada guardado**. Ocultar el menú no es la protección. La consola del servidor siempre tiene permiso.

**Cómo funciona**
- **Edición:** editas una copia de los valores. **Guardar** los envía al servidor, que valida el tipo y el rango de cada uno y los aplica todos o ninguno. **Cancelar** o `Esc` descarta los cambios.
- **Predeterminados de la sección** carga los valores de `config.lua` de esa sección; pulsa **Guardar** para aplicarlos. Un punto junto a un ajuste marca los valores distintos del predeterminado.
- **Aplicación:** los cambios guardados llegan al momento a todos los jugadores conectados, y también a los que entren después.
- **Almacenamiento:** los cambios se guardan en `data/admin.json`. Prevalecen sobre `config.lua` tras reiniciar, y las entradas no válidas del archivo se ignoran.
- **Solo en `config.lua`:** la autorización de llaves (`Config.Engine.authorize`) y la matriz de categorías (`Config.Categories`) solo se pueden cambiar en `config.lua`.

**Qué se puede cambiar desde el menú de administración**

| Sección | Ajustes |
|---|---|
| Cinturón y accidentes | Cinturón activado y tecla; expulsión activada; categorías permitidas; modelos permitidos y excluidos; **umbral** (velocidad mínima del impacto 20–250 km/h, cambio de velocidad 10–200 km/h, cambio relativo mínimo 10–95 %, ventana de medición 50–1000 ms); **fuerza** (horizontal 0–2×, vertical 0–12 m/s); tiempo de ragdoll; daño adicional opcional; protección entre expulsiones; aviso sonoro, velocidad e intervalo del aviso; bloqueo de salida |
| Motor | Arranque y parada propios; tecla |
| Luces | Luces propias activadas; tecla; pulsación larga para las largas; intermitentes activados y sus teclas |
| Crucero | Activado; teclas; velocidad mínima; paso; tiempo en el aire antes de cancelar |
| Nitro | Activado; tecla; potencia; consumo; carga mínima; espera entre usos; capacidad predeterminada y máxima; llamaradas |

---

## Ajustes de las funciones

Todo esto está en `config.lua`, comentado línea a línea. Los valores que también se pueden cambiar en el juego aparecen en el [menú de administración](#menú-de-administración-y-permisos).

```lua
Config.Features = { seatbelt = true, lights = true, indicators = true, cruise = true, engine = true, nitro = true }
```

Desactivar una función la elimina, junto con su tecla, para todo el servidor.

### Cinturón y expulsión

```lua
Config.Seatbelt = {
    mode = 'auto',          -- 'auto' | 'own' | 'external' | 'off'
    key = 'B',
    lockExit = true,        -- bloquear la tecla de salida abrochado (nunca las salidas forzadas)
    warnSound = true, warnSpeed = 20, warnInterval = 7000,
    ejection = {
        enabled = true,
        minSpeed = 75, minDelta = 40, minRatio = 0.45, window = 220,   -- umbral
        horizontalForce = 1.0, verticalForce = 2.5,                    -- fuerza
        ragdoll = 4000, damageEnabled = true, damage = 10, cooldown = 5000,
        categories = { 'car' }, allowModels = {}, denyModels = {},
    },
}
```

**Modos**
- `auto` usa `external` si `qbx_seatbelt` está iniciado y `own` si no.
- `own` es la mecánica propia.
- `external` solo muestra el estado de otro recurso, leído de `LocalPlayer.state.seatbelt` / `harness`, o del evento `seatbelt:client:ToggleSeatbelt` como respaldo.
- `off` desactiva el cinturón.

**Detección.** En cada fotograma, sin cinturón, el HUD sigue el vector completo de velocidad horizontal del vehículo. También lo hace con el vehículo parado, para que cuenten los golpes de otros vehículos. Hay expulsión solo si se cumple todo esto:
- el cambio es suficientemente grande,
- supone una fracción suficiente de la velocidad,
- el juego registró una colisión, o la carrocería perdió salud.

Cuentan los choques frontales, traseros, laterales y diagonales, los choques circulando marcha atrás y los golpes recibidos. Los saltos, aterrizajes y teletransportes se descartan. Con los umbrales predeterminados, las frenadas, curvas y derrapes quedan por debajo de los límites.

**Dirección.** El ocupante conserva su inercia y sale en sentido contrario al cambio de velocidad del vehículo:
- hacia delante en un choque frontal,
- hacia atrás al chocar contra una pared marcha atrás,
- por el lado del golpe en un impacto lateral.

**Vehículos permitidos.** Por defecto solo pueden expulsar los coches (nunca las bicicletas). En las categorías sin cinturón, como las motos si las permites, el ocupante cuenta siempre como desabrochado.

**Diagnóstico.** `/carhudcrash` (solo administradores) muestra en pantalla las muestras de velocidad, el cambio medido, la evidencia de colisión y el motivo de cada decisión. Las decisiones relevantes también se escriben en F8.

### Motor

```lua
Config.Engine = { key = 'G', authorize = 'auto' }
```

- `'auto'` usa `qbx_vehiclekeys` cuando está iniciado.
- `'none'` permite siempre al conductor.
- También puedes poner tu propia comprobación; ver [integración con llaves](#llaves).

### Luces e intermitentes

```lua
Config.Lights = { key = 'H', longPress = 350, leftKey = 'LEFT', rightKey = 'RIGHT', hazardKey = 'DOWN' }
```

### Control de crucero

```lua
Config.Cruise = { key = 'Y', upKey = 'PAGEUP', downKey = 'PAGEDOWN', step = 5, minSpeed = 30, maxAirTime = 1200 }
```

- Solo vehículos terrestres; nunca aeronaves ni embarcaciones.
- Solo controla el acelerador: no frena ni limita la velocidad.

### Nitro

```lua
Config.Nitro = {
    key = 'LSHIFT', defaultCapacity = 100.0, maxCapacity = 300.0,
    consumption = 12.5, minToActivate = 5.0, cooldown = 1500, power = 2.0,
    exhaustFx = true, persist = true, command = 'carhudnitro',
}
```

- **Ningún vehículo tiene nitro hasta que se instala**, con `/carhudnitro` (administradores) o con los exports de servidor. Ningún evento de cliente puede añadir carga.
- **El servidor valida:**
  - que quien lo usa es el conductor,
  - que el motor está encendido,
  - que la categoría admite nitro,
  - que hay carga suficiente.
- **Consumo y límites:** el servidor descuenta el consumo con el tiempo, aplica la espera entre usos y un límite de frecuencia, y publica el estado en un statebag del vehículo.
- **Se detiene** al soltar la tecla o agotarse la carga, y también al apagar el motor, dejar el asiento, destruir o borrar el vehículo, desconectarse o detener el recurso.
- **Almacenamiento:** se guarda por matrícula en `data/nitro.json`, según `Config.Nitro.persist`.
- **No disponible** en embarcaciones, aeronaves ni bicicletas.

### Avisos y otras opciones del HUD

```lua
Config.Warnings = { fuel = 15, engine = 35 }   -- porcentaje
Config.Hud = {
    accent = '#FE3555', defaultUnit = 'kmh', showForPassengers = true,
    requirePlayerLoaded = true, hideWhenHudHidden = true, hideWhenRadarHidden = false,
    hideNativeComponents = { 6, 7, 8, 9 },     -- textos nativos de nombre del vehículo, zona, clase y calle
    notify = 'hud',                            -- 'hud' | 'framework'
}
```

---

## Categorías de vehículos

| | Coche | Moto | Embarcación | Avión | Helicóptero | Bicicleta |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| HUD | ✔ | ✔ compacto | ✔ | ✔ variante aérea | ✔ variante aérea | — |
| Velocidad | ✔ | ✔ | ✔ | respecto al suelo | respecto al suelo | — |
| Marcha | ✔ | ✔ | — | — | — | — |
| RPM | ✔ | ✔ | ✔ | — | — | — |
| Acelerador / potencia | ✔ | ✔ | ✔ | ✔ | ✔ | — |
| Combustible y motor | ✔ | ✔ | ✔ | ✔ | ✔ | — |
| Altitud | — | — | — | sobre el mar y el suelo | sobre el suelo + velocidad vertical | — |
| Nitro (si está instalado) | ✔ | ✔ | — | — | — | — |
| Cinturón | ✔ | — | — | — | — | — |
| Luces | ✔ | ✔ | ✔ | — | — | — |
| Intermitentes / emergencia | ✔ | ✔ | — | — | — | — |
| Crucero | ✔ | ✔ | — | nunca | nunca | — |
| Arranque y parada del motor | ✔ | ✔ | ✔ | ✔ | ✔ | — |

- **Bicicletas:** nunca muestran el HUD, y en ellas no funciona ninguna función ni se lee telemetría. Los trenes no tienen HUD por defecto.
- **Aeronaves:** nunca reciben crucero, cinturón ni nitro, aunque se fuercen por modelo.
- Edita `Config.Categories` para cambiar la matriz. `Config.Models` la sobrescribe por nombre de spawn:

```lua
Config.Models = {
    ['mibici']   = { category = 'bicycle' },          -- bici personalizada mal clasificada
    ['ebike']    = { category = 'motorcycle' },       -- una e-bike que deba tener HUD
    ['sultanrs'] = { maxSpeed = 300, redline = 9000 },
    ['polmav']   = { hud = false },
}
```

---

## Ubicación sobre el minimapa

- **Contenido:** la calle es la línea principal y la zona va debajo. En el mar o fuera de carretera solo se muestra la zona.
- **Lectura:** la calle y la zona se leen con natives cada 500 ms y solo se envían si cambian. El rumbo se lee cada 150 ms, con 8° de histéresis para que no parpadee en los límites.
- **Visibilidad:** necesita que el HUD esté visible **y** que el minimapa esté visible (no el mapa ampliado). Si solo se oculta el minimapa, solo se oculta la ubicación.
- **Colocación:** se ancla al rectángulo real del minimapa (alineación de GTA, relación de aspecto y zona segura). Por defecto tiene su mismo ancho y queda 12 px por encima (a 1080p, proporcional a la resolución), desplazada según la posición predeterminada.

```lua
Config.Location = {
    enabled = true,
    placeRate = 500, headingRate = 150, hysteresis = 8,
    gap = 12,                                                  -- px a 1080p por encima del minimapa
    default = { x = 20 / 1080, y = -37 / 1080, scale = 1.02 }, -- desplazamiento y tamaño predeterminados
    minimap = { posX = -0.0045, posY = 0.002, sizeX = 0.150, sizeY = 0.188888 },
}
```

**Calibrar la posición predeterminada**
1. En el juego, abre `/carhud` → **Mover HUD** y arrastra la barra de ubicación hasta donde la quieras.
2. Cierra el menú y ejecuta `/carhud layout`. En F8 aparece algo como
   `{"location":{"x":0.0185,"y":-0.0342,"scale":1.02,...}}`.
3. Copia `x`, `y` y `scale` en `Config.Location.default` y reinicia el recurso.

`x` e `y` son fracciones del alto de pantalla (20 / 1080 = 20 px a 1080p), así que la posición se mantiene en otras resoluciones.

Si tu servidor mueve o redimensiona el minimapa con `SetMinimapComponentPosition`, copia esos mismos valores en `Config.Location.minimap`.

---

## Valores del servidor frente a preferencias del jugador

| Dónde | Qué | Quién lo cambia |
|---|---|---|
| `config.lua` | Valores predeterminados y límites del servidor | El propietario del servidor (se aplica al reiniciar) |
| `data/admin.json` | Valores guardados desde `/carhudadmin`; prevalecen sobre `config.lua` | Los administradores, en el juego |
| Cliente del jugador (KVP) | Preferencias personales dentro de los límites del servidor | Cada jugador, en `/carhud` |
| `data/nitro.json` | Nitro instalado y carga por matrícula | Administradores y exports de servidor |

- Un jugador nuevo recibe los valores de `config.lua`, incluidas las posiciones del velocímetro y de la ubicación. No necesita las preferencias de nadie más.
- **Restaurar todo** (menú del jugador) devuelve a ese jugador a los valores del servidor. **Posición original** restablece solo las posiciones.
- **Predeterminados de la sección** (menú de administración) carga los valores de `config.lua` de esa sección.
- Para empezar un servidor desde cero, vacía el contenido de `data/admin.json` y `data/nitro.json` (deja `{}`).

---

## Exports, eventos e integraciones

### Exports de cliente

| Export | Descripción |
|---|---|
| `IsSeatbeltOn()` | `true` si el jugador lleva puesto el cinturón (propio o externo) |
| `SetHudVisible(visible)` | Oculta (`false`) o muestra (`true`) el HUD desde tu recurso. Cada recurso tiene su propia marca, que se borra automáticamente si ese recurso se detiene |
| `IsHudVisible()` | Si el HUD está visible ahora |
| `GetCruiseSpeed()` | Velocidad objetivo del crucero en m/s (`0` si está inactivo) |
| `OpenSettings()` | Abre el menú del jugador |
| `SetEngineAuthorizer(fn)` | Registra tu comprobación de llaves: `fn(vehicle)` devuelve `true`/`false` |

```lua
-- Ocultar el HUD durante una cinemática
exports.vortexlabs_carhud:SetHudVisible(false)
-- ...
exports.vortexlabs_carhud:SetHudVisible(true)

if exports.vortexlabs_carhud:IsSeatbeltOn() then
    -- el jugador lleva el cinturón
end
```

### Exports de servidor (nitro)

`vehicle` puede ser una entidad de vehículo o una matrícula.

```lua
exports.vortexlabs_carhud:EquipNitro(vehicle, 100)        -- capacidad (opcional), cantidad (opcional) → booleano
exports.vortexlabs_carhud:RefillNitro(vehicle, 25)        -- sin cantidad: llenar → booleano
exports.vortexlabs_carhud:RemoveNitro(vehicle)            -- → booleano
local info = exports.vortexlabs_carhud:GetNitro(vehicle)  -- { plate, capacity, amount, active } o nil
```

### Eventos

| Evento | Lado | Descripción |
|---|---|---|
| `vortexlabs_carhud:notify` | servidor → cliente | Muestra un aviso encima del HUD (o mediante el framework si `Config.Hud.notify = 'framework'`): `TriggerClientEvent('vortexlabs_carhud:notify', source, 'Texto', 'info')`. `kind`: `'info'`, `'warn'` o `'danger'` |

Los demás eventos `vortexlabs_carhud:*` son internos (menú de administración y nitro). El servidor los valida y no están pensados para que los llamen otros recursos.

### State bags

- `LocalPlayer.state.seatbelt`: lo fija el cinturón propio (modo `own`). Otros recursos pueden leerlo.
- `Entity(vehicle).state.fcarhud_nitro`: estado del nitro publicado por el servidor. Es de solo lectura; si un cliente lo cambia, el servidor lo restablece.

### Llaves

```lua
-- config.lua: tu propia comprobación (sustitúyela por el export real de tu sistema de llaves)
Config.Engine.authorize = function(vehicle)
    return exports.your_keys:HasKey(vehicle)
end
```

```lua
-- o desde tu recurso de llaves (cliente)
exports.vortexlabs_carhud:SetEngineAuthorizer(function(vehicle)
    return true -- tu comprobación
end)
```

Si la comprobación produce un error, se deniega el arranque y el error se imprime como mucho una vez por minuto, no en cada pulsación.

---

## Solución de problemas

| Problema | Comprueba |
|---|---|
| Dos HUD en pantalla | Detén tu otro HUD de vehículos (`qbx_hud`, `qb-hud`, `esx_hud`…) |
| El HUD no aparece | ¿Estás en un vehículo compatible (no una bicicleta) y en el asiento del conductor (o está activado `showForPassengers`)? Con framework, ¿ha cargado el personaje? ¿Algún recurso llama a `SetHudVisible(false)`? |
| La tecla del cinturón no hace nada | Con `qbx_seatbelt` iniciado, el HUD solo *muestra* su estado (modo `external`). Usa la tecla de ese recurso, o pon `Config.Seatbelt.mode = 'own'` y detenlo |
| El motor no arranca | Revisa tu sistema de llaves, o pon `Config.Engine.authorize = 'none'` para probar |
| `Y` activa dos cruceros | Desactiva el otro crucero o cambia una tecla |
| El combustible muestra «—» | El proveedor aún no tiene dato para ese vehículo. Revisa `Config.Fuel.provider` o prueba `'native'` |
| Porcentaje de combustible incorrecto en modo nativo | Pon `Config.Fuel.nativeScale = 'percent'` si otro script escribe valores 0–100 |
| La ubicación queda mal colocada | ¿Tu servidor mueve el minimapa? Ajusta `Config.Location.minimap` o colócala con **Mover HUD** |
| Las teclas no cambian tras editar la configuración | FiveM conserva las teclas personalizadas por los jugadores. Las nuevas predeterminadas llegan al reconectar |
| `/carhudadmin` dice que no tienes permiso | Añade la línea ACE de la [instalación](#instalación) o revisa `Config.Permissions.frameworkGroups` |

Activa `Config.Debug = true` para ver mensajes de diagnóstico adicionales en F8 y en la consola del servidor. Está desactivado por defecto.

---

## Limitaciones conocidas

- **RPM:** el juego solo da RPM normalizadas (0–1). Se convierten con el `redline` de cada perfil, configurable por categoría y modelo.
- **La velocidad en aeronaves** es velocidad horizontal respecto al suelo, no velocidad aerodinámica, y así se rotula.
- **Luces:** el control propio de luces fija el modo de luces del vehículo. Al detener el recurso, las luces vuelven al control del juego (modo 0), lo que puede apagar unas luces encendidas con el HUD. La sincronización de las largas depende del juego.
- **Las llamaradas del nitro** son un efecto local: solo las ve el conductor.
- **El control de crucero** solo usa el acelerador. En pendientes muy pronunciadas puede no mantener la velocidad exacta, y nunca frena.
- **La altura sobre el suelo** sobre el agua depende de `GetEntityHeightAboveGround`.
- **La posición del minimapa** sale de la disposición estándar del juego. Con minimapas personalizados hay que ajustar `Config.Location.minimap`.
- **Los cambios de teclas** hechos en `/carhudadmin` llegan a cada jugador al reconectar, salvo que ya haya personalizado esa tecla.
- **El idioma** se fija para todo el servidor; no hay elección de idioma por jugador.

**Probado hasta ahora**
- El código se comprueba de forma estática: sintaxis, y cada native verificada contra la base de datos de natives de FiveM.
- La lógica Lua se prueba en un entorno simulado de FiveM, para cliente y servidor.
- La interfaz se prueba con pruebas automáticas en navegador, incluidas pruebas con fotogramas reales de la visibilidad sincronizada, 6 resoluciones y 4 zonas seguras.
- **En el juego,** se ha usado en un servidor Qbox con `ox_fuel`, con decisiones reales de choque y expulsión y con el menú del jugador.
- **ESX, QBCore, LegacyFuel y cdn-fuel** son compatibles mediante adaptadores escritos a partir del código oficial de esos recursos y probados en simulación. Todavía no se han probado en un servidor real.

---

## Informar de un error

Incluye, por favor:

1. La versión de `vortexlabs_carhud` (aparece en la consola del servidor al iniciar) y la build de tu servidor FiveM.
2. Tu framework, combustible, cinturón y llaves, y cualquier otro HUD que uses.
3. Los pasos exactos para reproducirlo y el modelo del vehículo.
4. Las líneas de error de F8 y de la consola del servidor que empiecen por `[vortexlabs_carhud]` o `SCRIPT ERROR`.
5. Para problemas de expulsión, la salida de `/carhudcrash` en ese choque.
6. Si también ocurre con `Config.Debug = true` y los demás HUD detenidos.

Envíalo a VortexLabs por el canal donde obtuviste el recurso.

---

## Créditos

Diseño y desarrollo: **VortexLabs**. Licencias de terceros: [THIRD_PARTY.md](THIRD_PARTY.md).
