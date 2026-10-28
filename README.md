<<<<<<< HEAD
# VortexLabs Car HUD (`vortexlabs_carhud`) · v1.0.0

A free vehicle HUD for FiveM by **VortexLabs**. It shows a single bottom-right speedometer with a nitro ring, side indicators, a throttle bar and a status row, plus a location bar above the minimap. It also adds its own driving features: seatbelt with crash ejection, lights and indicators, cruise control, engine start/stop and server-validated nitro.

It runs on **standalone, ESX, QBCore and Qbox** with no required dependencies.

*Versión en español: [README.es.md](README.es.md)*

---

## Contents

1. [Features](#features)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Frameworks](#frameworks)
5. [Fuel](#fuel)
6. [Language and units](#language-and-units)
7. [Controls](#controls)
8. [Player menu](#player-menu)
9. [Admin menu and permissions](#admin-menu-and-permissions)
10. [Feature settings](#feature-settings)
11. [Vehicle categories](#vehicle-categories)
12. [Location above the minimap](#location-above-the-minimap)
13. [Server defaults vs. player preferences](#server-defaults-vs-player-preferences)
14. [Exports, events and integrations](#exports-events-and-integrations)
15. [Troubleshooting](#troubleshooting)
16. [Known limitations](#known-limitations)
17. [Reporting a bug](#reporting-a-bug)
18. [Credits](#credits)

---

## Features

**HUD**
- **Speedometer:** a segmented arc with gear, unit and RPM (where the vehicle has them). The arc scale is estimated per model.
- **Nitro ring** above the speedometer. It only appears on vehicles that have nitro installed and shows the remaining charge. The centre lights up while nitro is in use.
- **Indicators** on both sides, showing the vehicle's real state; hazards blink in sync.
- **Throttle bar** under the speedometer.
- **Status row:** seatbelt, lights and cruise │ fuel and engine. Aircraft show altitude instead.
- **Engine health colour** changes gradually as damage grows and goes back gradually after a repair. A separate "Engine damaged" warning appears below the configured threshold.
- **Location bar above the minimap:** street, area and heading (8 compass points). It matches the minimap's width and position at any resolution and safe zone.
- **Shared visibility:** the speedometer, nitro, status row and location appear and disappear together, with one 140 ms fade.
- Never shown on foot or on bicycles. It hides as soon as the player starts to get out, in the pause menu, and when another resource hides the HUD.
- Each vehicle type has its own profile: car, motorcycle (compact), boat, plane and helicopter.
- **VortexLabs design:** black and charcoal surfaces with neutral greys. Values in their normal range stay neutral; coral appears only for what needs attention (the top of the speed arc, the unbuckled seatbelt, serious damage) and for the menus' main action, selection and focus. Players can still pick their own accent colour.

**Driving features** (each one can be disabled server-wide)
- **Seatbelt:** key, sounds, unbuckled warning and exit lock while buckled.
- **Crash ejection** without a seatbelt: frontal, rear, side and diagonal impacts are detected from the velocity vector, with collision evidence required. It also works with an external seatbelt resource (`qbx_seatbelt` is detected automatically).
- **Lights:** tap for lights, hold for high beams. Left/right indicators and hazards.
- **Cruise control:** set, cancel, increase and decrease. Land vehicles only.
- **Engine start/stop**, respecting vehicle keys (`qbx_vehiclekeys` automatically, or your own check).
- **Nitro:** installed per vehicle by admins or server exports. The charge is consumed and validated on the server and saved per plate.

**Menus**
- **Player menu `/carhud`:** units, accent colour, visible modules, numeric values, sound volume, size, position and opacity, and location on/off, size and position. Preferences are saved per player.
- **Admin menu `/carhudadmin`:** seatbelt and crashes, engine, lights, cruise and nitro. Permissions are checked on the server, and changes are saved without a database.
- Interface in **English and Spanish**.

---

## Requirements

**Required:** only FiveM. No database, inventory or library is needed.

**Optional, detected automatically:**

| Type | Supported |
|---|---|
| Framework | Qbox (`qbx_core`), QBCore (`qb-core`), ESX (`es_extended`), or standalone |
| Fuel | `ox_fuel`, `LegacyFuel`, `cdn-fuel`, or the native fuel level |
| Seatbelt | its own seatbelt, or `qbx_seatbelt` as an external source |
| Vehicle keys | `qbx_vehiclekeys`, or any keys resource through a function/export |

---

## Installation

1. Download `vortexlabs_carhud-v1.0.0.zip` from the [Releases](../../releases) page and extract it into your `resources` folder. You should end up with `resources/vortexlabs_carhud/fxmanifest.lua`.
   The release ZIP contains only what the server needs. A clone of the repository also works, but it brings the development folders (`web/`, `preview/`, `tools/`, `dev/`), which FiveM ignores.
2. In `server.cfg`, add it **after** your framework, fuel and keys resources:

   ```cfg
   ensure vortexlabs_carhud
   ```

3. Grant the admin permission (used by `/carhudadmin`, `/carhudcrash` and `/carhudnitro`):

   ```cfg
   add_ace group.admin vortexlabs_carhud.admin allow
   ```

4. Stop any other vehicle HUD (for example `qbx_hud`, `qb-hud` or `esx_hud`), otherwise two HUDs show at once.
5. Restart the server. The server console prints what was detected, for example
   `[vortexlabs_carhud] v1.0.0 · Framework: qbox · Fuel: auto · Seatbelt: auto`.

The interface ships already built (`html/`), so you don't need Node.js or any build step.

**Start order.** If `vortexlabs_carhud` starts before the framework or the fuel resource, it detects them when they start. The recommended order is still framework → fuel → keys → `vortexlabs_carhud`.

**Restarting.** `restart vortexlabs_carhud` works both on foot and inside a vehicle. When the resource stops, it hands the lights back to the game, resets the seatbelt and its exit lock, releases the interface focus and stops any active nitro.

### Overlapping resources

| Resource | What happens | What to do |
|---|---|---|
| `qbx_hud`, `qb-hud`, `esx_hud`… | Two vehicle HUDs | Stop the other HUD |
| `qbx_seatbelt` | Detected: the HUD shows its state and its own seatbelt mechanic stays off | Nothing. To use the built-in mechanic instead, stop `qbx_seatbelt` and set `Config.Seatbelt.mode = 'own'` |
| Another seatbelt script | Two seatbelts on the same key | Set `Config.Seatbelt.mode = 'external'` or disable the other one |
| `qbx_cruise` / other cruise scripts | Both use `Y` by default | Disable one or change a key |
| `qbx_vehiclekeys` | It has its own engine key | Use one of the two keys; the HUD respects its keys either way |

---

## Frameworks

`Config.Framework = 'auto'` checks for **Qbox** (`qbx_core`), then **QBCore** (`qb-core`), then **ESX** (`es_extended`), and falls back to standalone. Qbox is checked first because it also provides `qb-core`. You can also set the framework explicitly:

```lua
Config.Framework = 'auto'        -- or 'qbox' | 'qbcore' | 'esx' | 'standalone'
```

The framework is only used for three things:
- **Waiting for the character to load:** with `Config.Hud.requirePlayerLoaded`, the HUD stays hidden until the character has loaded.
- **Notifications:** only when `Config.Hud.notify = 'framework'`; otherwise notices appear above the HUD.
- **Admin groups:** `Config.Permissions.frameworkGroups`.

All framework calls are protected. If the framework restarts or stops, the HUD keeps working as standalone.

---

## Fuel

The fuel level is **read only**: this resource never changes the fuel level, consumption or refuelling.

```lua
Config.Fuel = {
    provider = 'auto',     -- 'auto' | 'ox_fuel' | 'LegacyFuel' | 'cdn-fuel' | 'native'
    nativeScale = 'tank',  -- native mode: 'tank' (litres of the handling tank) | 'percent' (0–100)
    decor = '_FUEL_LEVEL', -- decorator used by LegacyFuel / cdn-fuel
}
```

| Provider | Read from |
|---|---|
| `ox_fuel` | `Entity(vehicle).state.fuel` |
| `LegacyFuel` | `exports.LegacyFuel:GetFuel(vehicle)`, after checking the `_FUEL_LEVEL` decorator exists |
| `cdn-fuel` | `exports['cdn-fuel']:GetFuel(vehicle)`, after checking the decorator |
| `native` | `GetVehicleFuelLevel` |

- `'auto'` picks the first one that is started: `ox_fuel`, then `cdn-fuel`, then `LegacyFuel`, then native.
- **0 means an empty tank.** If the provider has no value yet, the fuel module is dimmed and shows "—" without warnings.
- If the provider stops, or its export keeps failing, the HUD falls back to the native reading and switches back when the provider returns.
- Vehicles that don't use fuel hide the fuel module.

---

## Language and units

```lua
Config.Locale = 'en'   -- 'en' | 'es'
```

The language applies to the whole server: menus, notices, key descriptions and console messages. Players can't pick their own language.

All texts live in `locales/en.json` and `locales/es.json`. Each file has a `game` section (Lua) and a `ui` section (interface). Any missing text falls back to English.

To add a language, copy `en.json` to, for example, `fr.json`, translate the values (never the keys) and set `Config.Locale = 'fr'`.

**Units.** `Config.Hud.defaultUnit = 'kmh'` (or `'mph'`) is the starting unit. Each player can switch units in `/carhud` if `Config.Player.allowUnit = true`. The arc keeps the same physical scale in both units: 100 km/h fills the same arc as 62 mph.

---

## Controls

| Action | Default key | Config |
|---|---|---|
| Seatbelt | `B` | `Config.Seatbelt.key` |
| Lights (tap) · high beams (hold) | `H` | `Config.Lights.key`, `longPress` |
| Left / right indicator | `←` / `→` | `Config.Lights.leftKey`, `rightKey` |
| Hazards | `↓` | `Config.Lights.hazardKey` |
| Cruise: set/cancel · faster · slower | `Y` · `Page Up` · `Page Down` | `Config.Cruise.key`, `upKey`, `downKey` |
| Engine start/stop | `G` | `Config.Engine.key` |
| Nitro (hold) | `Left Shift` | `Config.Nitro.key` |
| Open settings | none (`/carhud`) | `Config.Player.settingsKey` |

**Rebinding.** Players change keys in **GTA Settings → Key Bindings → FiveM**. The keys in the config, or in the admin menu, are only *defaults*: FiveM never overwrites a key a player has already customised, and a changed default reaches each player the next time they connect. Keys are only registered for features that are enabled.

| Command | Who | What it does |
|---|---|---|
| `/carhud` | everyone | Opens the player menu |
| `/carhud layout` | everyone | Prints your saved position and size to the F8 console (see [Location](#location-above-the-minimap)) |
| `/carhud perf [seconds]` | everyone | Measures the resource's Lua and interface cost and prints it to F8 |
| `/carhudadmin` | admins | Opens the admin menu |
| `/carhudcrash` | admins | Turns the ejection diagnostics on or off (off by default) |
| `/carhudnitro equip [capacity]` · `refill [amount]` · `remove` · `info` | admins | Nitro on the vehicle you are in |
| `carhudnitro <action> <playerId> [value]` | server console | The same, for a player's vehicle |

---

## Player menu

`/carhud` opens the player menu. It is the only part of the HUD that takes mouse focus. `Esc`, **Done** or opening the pause menu closes it and releases the focus.

- **Units:** km/h or mph.
- **Accent colour:** swatches or a hex code.
- **Visible modules:** RPM, throttle, fuel, engine, nitro, telltales, altitude and notices.
- **Show numeric values:** small percentages for fuel, engine and nitro (off by default).
- **Sound volume**, with a test button.
- **Position, scale and opacity:**
  - Speedometer size from 80 % to 150 %, with **Reset size**.
  - Opacity.
  - **Move HUD** lets you drag the speedometer and the location bar. Both always stay inside the safe zone.
  - **Default position** puts both back at the server's default position and keeps every other preference.
- **Location:** show or hide, and its own size. Its width always matches the minimap. **Reset size** returns to the server default.
- **Reset all** returns every preference to the server defaults.

What players can change is limited by `Config.Player`:

```lua
Config.Player = {
    allowUnit = true, allowColor = true, allowLayout = true, allowModules = true,
    scaleMin = 0.8, scaleMax = 1.5,   -- size range (80–150 %)
    opacityMin = 0.4,
    maxVolume = 1.0, defaultVolume = 0.6,
    settingsKey = '',                 -- optional key to open the menu
    command = 'carhud',
}
```

Every value is checked when it is loaded and when it is saved. Invalid values are discarded, and players can never go past these limits or turn on a feature the server has disabled.

---

## Admin menu and permissions

`/carhudadmin` opens a menu separate from the player menu, with five sections: **Seatbelt and crashes**, **Engine**, **Lights**, **Cruise** and **Nitro**.

**Permissions.** A player is an admin if they have the ACE permission **or** belong to one of the framework groups:

```lua
Config.Permissions = {
    ace = 'vortexlabs_carhud.admin',
    frameworkGroups = { 'admin', 'god', 'superadmin' },
}
```

```cfg
# server.cfg — give the permission to the admin group
add_ace group.admin vortexlabs_carhud.admin allow
# and put a player in that group (use your own identifier)
add_principal identifier.license:<your-license> group.admin
```

The server checks the permission every time the menu opens and **on every save**. Hiding the menu is not the protection. The server console always has permission.

**How it works**
- **Editing:** you edit a copy of the values. **Save** sends them to the server, which validates the type and range of each one and applies all of them or none. **Cancel** or `Esc` discards your changes.
- **Section defaults** loads the `config.lua` values for that section; press **Save** to apply them. A dot next to a setting marks values that differ from the default.
- **Applying:** saved changes reach every connected player immediately, and players who join later too.
- **Storage:** changes are saved in `data/admin.json`. They take priority over `config.lua` after a restart, and invalid entries in the file are ignored.
- **Config-only settings:** key authorisation (`Config.Engine.authorize`) and the category matrix (`Config.Categories`) can only be changed in `config.lua`.

**What the admin menu can change**

| Section | Settings |
|---|---|
| Seatbelt and crashes | Seatbelt on/off and key; ejection on/off; allowed categories; allowed and excluded models; **threshold** (minimum impact speed 20–250 km/h, velocity change 10–200 km/h, minimum relative change 10–95 %, measurement window 50–1000 ms); **force** (horizontal 0–2×, vertical 0–12 m/s); ragdoll time; optional extra damage; protection between ejections; warning sound, warning speed and interval; exit lock |
| Engine | Own engine start/stop; key |
| Lights | Own lights on/off; key; long press for high beams; indicators on/off and their keys |
| Cruise | On/off; keys; minimum speed; step; airborne time before cancelling |
| Nitro | On/off; key; power; consumption; minimum charge; cooldown; default and maximum capacity; exhaust flames |

---

## Feature settings

All of these are in `config.lua`, which is commented line by line. The values that can also be changed in game are listed in the [admin menu](#admin-menu-and-permissions).

```lua
Config.Features = { seatbelt = true, lights = true, indicators = true, cruise = true, engine = true, nitro = true }
```

Disabling a feature removes it, and its key, for the whole server.

### Seatbelt and ejection

```lua
Config.Seatbelt = {
    mode = 'auto',          -- 'auto' | 'own' | 'external' | 'off'
    key = 'B',
    lockExit = true,        -- block the exit key while buckled (never forced exits)
    warnSound = true, warnSpeed = 20, warnInterval = 7000,
    ejection = {
        enabled = true,
        minSpeed = 75, minDelta = 40, minRatio = 0.45, window = 220,   -- threshold
        horizontalForce = 1.0, verticalForce = 2.5,                    -- force
        ragdoll = 4000, damageEnabled = true, damage = 10, cooldown = 5000,
        categories = { 'car' }, allowModels = {}, denyModels = {},
    },
}
```

**Modes**
- `auto` uses `external` if `qbx_seatbelt` is running, and `own` otherwise.
- `own` is the built-in mechanic.
- `external` only shows another resource's state, read from `LocalPlayer.state.seatbelt` / `harness`, or from the `seatbelt:client:ToggleSeatbelt` event as a fallback.
- `off` disables the seatbelt.

**Detection.** Every frame, while unbuckled, the HUD tracks the vehicle's full horizontal velocity vector. It also does this when the vehicle is stopped, so hits from other vehicles count. An ejection happens only when all of these are true:
- the change is large enough,
- it is a large enough share of the speed,
- the game registered a collision, or the bodywork lost health.

Frontal, rear, side and diagonal crashes, reversing into obstacles, and hits received all count. Jumps, landings and teleports are discarded. With the default thresholds, braking, turns and drifts stay below the limits.

**Direction.** The occupant keeps their inertia and leaves opposite to the vehicle's velocity change:
- forward in a frontal crash,
- backwards when reversing into a wall,
- out of the hit side in a side impact.

**Allowed vehicles.** By default only cars can eject (never bicycles). In categories without a seatbelt, such as motorcycles when you allow them, the rider always counts as unbuckled.

**Diagnostics.** `/carhudcrash` (admins only) shows the speed samples, the measured change, the collision evidence and the reason for each decision on screen. Relevant decisions are also printed to F8.

### Engine

```lua
Config.Engine = { key = 'G', authorize = 'auto' }
```

- `'auto'` uses `qbx_vehiclekeys` when it is started.
- `'none'` always allows the driver.
- You can also set your own check; see [keys integration](#vehicle-keys).

### Lights and indicators

```lua
Config.Lights = { key = 'H', longPress = 350, leftKey = 'LEFT', rightKey = 'RIGHT', hazardKey = 'DOWN' }
```

### Cruise control

```lua
Config.Cruise = { key = 'Y', upKey = 'PAGEUP', downKey = 'PAGEDOWN', step = 5, minSpeed = 30, maxAirTime = 1200 }
```

- Land vehicles only; never aircraft or boats.
- It controls the throttle only: it doesn't brake or limit speed.

### Nitro

```lua
Config.Nitro = {
    key = 'LSHIFT', defaultCapacity = 100.0, maxCapacity = 300.0,
    consumption = 12.5, minToActivate = 5.0, cooldown = 1500, power = 2.0,
    exhaustFx = true, persist = true, command = 'carhudnitro',
}
```

- **No vehicle has nitro until it is installed**, either with `/carhudnitro` (admins) or with the server exports. No client event can add charge.
- **Validated on the server:**
  - the player using it is the driver,
  - the engine is running,
  - the category allows nitro,
  - there is enough charge.
- **Consumption and limits:** the server deducts consumption over time, applies the cooldown and a rate limit, and publishes the state in a vehicle statebag.
- **Stops** when the key is released or the charge runs out, and also on engine off, leaving the seat, the vehicle being destroyed or deleted, disconnecting, or the resource stopping.
- **Storage:** saved per plate in `data/nitro.json`, controlled by `Config.Nitro.persist`.
- **Not available** on boats, aircraft or bicycles.

### Warnings and other HUD options

```lua
Config.Warnings = { fuel = 15, engine = 35 }   -- percent
Config.Hud = {
    accent = '#FE3555', defaultUnit = 'kmh', showForPassengers = true,
    requirePlayerLoaded = true, hideWhenHudHidden = true, hideWhenRadarHidden = false,
    hideNativeComponents = { 6, 7, 8, 9 },     -- native vehicle name, area, class and street texts
    notify = 'hud',                            -- 'hud' | 'framework'
}
```

---

## Vehicle categories

| | Car | Motorcycle | Boat | Plane | Helicopter | Bicycle |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| HUD | ✔ | ✔ compact | ✔ | ✔ air variant | ✔ air variant | — |
| Speed | ✔ | ✔ | ✔ | ground speed | ground speed | — |
| Gear | ✔ | ✔ | — | — | — | — |
| RPM | ✔ | ✔ | ✔ | — | — | — |
| Throttle / power | ✔ | ✔ | ✔ | ✔ | ✔ | — |
| Fuel and engine | ✔ | ✔ | ✔ | ✔ | ✔ | — |
| Altitude | — | — | — | above sea and ground | above ground + vertical speed | — |
| Nitro (if installed) | ✔ | ✔ | — | — | — | — |
| Seatbelt | ✔ | — | — | — | — | — |
| Lights | ✔ | ✔ | ✔ | — | — | — |
| Indicators / hazards | ✔ | ✔ | — | — | — | — |
| Cruise | ✔ | ✔ | — | never | never | — |
| Engine start/stop | ✔ | ✔ | ✔ | ✔ | ✔ | — |

- **Bicycles** never show the HUD, and no feature or telemetry runs on them. Trains have no HUD by default.
- **Aircraft** never get cruise, seatbelt or nitro, even when forced per model.
- Edit `Config.Categories` to change the matrix. `Config.Models` overrides it per spawn name:

```lua
Config.Models = {
    ['mybike']   = { category = 'bicycle' },          -- custom bicycle with the wrong class
    ['ebike']    = { category = 'motorcycle' },       -- an e-bike that should have a HUD
    ['sultanrs'] = { maxSpeed = 300, redline = 9000 },
    ['polmav']   = { hud = false },
}
```

---

## Location above the minimap

- **Content:** the street is the main line and the area sits below it. At sea or off-road only the area is shown.
- **Reading:** street and area are read with natives every 500 ms and only sent when they change. The heading is read every 150 ms, with 8° of hysteresis so it doesn't flicker at the boundaries.
- **Visibility:** it needs the HUD to be visible **and** the minimap to be visible (not the big map). If only the minimap hides, only the location hides.
- **Placement:** it is anchored to the real minimap rectangle (GTA alignment, aspect ratio and safe zone). By default it is as wide as the minimap and sits 12 px above it (at 1080p, scaled with the resolution), shifted by the default offset.

```lua
Config.Location = {
    enabled = true,
    placeRate = 500, headingRate = 150, hysteresis = 8,
    gap = 12,                                                  -- px at 1080p above the minimap
    default = { x = 20 / 1080, y = -37 / 1080, scale = 1.02 }, -- default offset and size
    minimap = { posX = -0.0045, posY = 0.002, sizeX = 0.150, sizeY = 0.188888 },
}
```

**Calibrating the default position**
1. In game, open `/carhud` → **Move HUD** and drag the location bar where you want it.
2. Close the menu and run `/carhud layout`. F8 prints something like
   `{"location":{"x":0.0185,"y":-0.0342,"scale":1.02,...}}`.
3. Copy `x`, `y` and `scale` into `Config.Location.default` and restart the resource.

`x` and `y` are fractions of the screen height (20 / 1080 = 20 px at 1080p), so the position stays the same at other resolutions.

If your server moves or resizes the minimap with `SetMinimapComponentPosition`, copy the same values into `Config.Location.minimap`.

---

## Server defaults vs. player preferences

| Where | What | Who changes it |
|---|---|---|
| `config.lua` | Server defaults and limits | Server owner (restart to apply) |
| `data/admin.json` | Values saved from `/carhudadmin`; they override `config.lua` | Admins, in game |
| Player's client (KVP) | Personal preferences within the server limits | Each player, in `/carhud` |
| `data/nitro.json` | Installed nitro and charge per plate | Admins and server exports |

- A new player gets the `config.lua` defaults, including the speedometer and location positions. They don't need anyone else's preferences.
- **Reset all** (player menu) returns that player to the server defaults. **Default position** resets only the positions.
- **Section defaults** (admin menu) loads the `config.lua` values for that section.
- To start a server from scratch, delete the contents of `data/admin.json` and `data/nitro.json` (leave `{}`).

---

## Exports, events and integrations

### Client exports

| Export | Description |
|---|---|
| `IsSeatbeltOn()` | `true` if the player is wearing the seatbelt (own or external) |
| `SetHudVisible(visible)` | Hides (`false`) or shows (`true`) the HUD from your resource. Each resource has its own flag, which is cleared automatically if that resource stops |
| `IsHudVisible()` | Whether the HUD is currently visible |
| `GetCruiseSpeed()` | Cruise target speed in m/s (`0` when inactive) |
| `OpenSettings()` | Opens the player menu |
| `SetEngineAuthorizer(fn)` | Registers your key check: `fn(vehicle)` returns `true`/`false` |

```lua
-- Hide the HUD during a cutscene
exports.vortexlabs_carhud:SetHudVisible(false)
-- ...
exports.vortexlabs_carhud:SetHudVisible(true)

if exports.vortexlabs_carhud:IsSeatbeltOn() then
    -- player is buckled
end
```

### Server exports (nitro)

`vehicle` can be a vehicle entity or a plate string.

```lua
exports.vortexlabs_carhud:EquipNitro(vehicle, 100)        -- capacity (optional), amount (optional) → boolean
exports.vortexlabs_carhud:RefillNitro(vehicle, 25)        -- without an amount: fill up → boolean
exports.vortexlabs_carhud:RemoveNitro(vehicle)            -- → boolean
local info = exports.vortexlabs_carhud:GetNitro(vehicle)  -- { plate, capacity, amount, active } or nil
```

### Events

| Event | Side | Description |
|---|---|---|
| `vortexlabs_carhud:notify` | server → client | Shows a notice above the HUD (or through the framework if `Config.Hud.notify = 'framework'`): `TriggerClientEvent('vortexlabs_carhud:notify', source, 'Text', 'info')`. `kind`: `'info'`, `'warn'` or `'danger'` |

The other `vortexlabs_carhud:*` events are internal (admin menu and nitro). They are validated on the server and are not meant to be called by other resources.

### State bags

- `LocalPlayer.state.seatbelt`: set by the built-in seatbelt (`own` mode). Other resources can read it.
- `Entity(vehicle).state.fcarhud_nitro`: nitro state published by the server. It is read only; if a client changes it, the server resets it.

### Vehicle keys

```lua
-- config.lua: your own check (replace with the real export of your keys resource)
Config.Engine.authorize = function(vehicle)
    return exports.your_keys:HasKey(vehicle)
end
```

```lua
-- or from your keys resource (client)
exports.vortexlabs_carhud:SetEngineAuthorizer(function(vehicle)
    return true -- your check
end)
```

If the check raises an error, starting the engine is denied and the error is printed at most once a minute, not on every press.

---

## Troubleshooting

| Problem | Check |
|---|---|
| Two HUDs on screen | Stop your other vehicle HUD (`qbx_hud`, `qb-hud`, `esx_hud`…) |
| HUD never appears | Are you in a supported vehicle (not a bicycle) and in the driver's seat (or is `showForPassengers` on)? With a framework, has the character loaded? Is another resource calling `SetHudVisible(false)`? |
| Seatbelt key does nothing | With `qbx_seatbelt` running, the HUD only *shows* its state (`external` mode). Use that resource's key, or set `Config.Seatbelt.mode = 'own'` and stop it |
| Engine won't start | Check your keys resource, or set `Config.Engine.authorize = 'none'` to test |
| `Y` toggles two cruise controls | Disable the other cruise script or change a key |
| Fuel shows "—" | The fuel provider has no value for that vehicle yet. Check `Config.Fuel.provider`, or try `'native'` |
| Fuel shows the wrong % in native mode | Set `Config.Fuel.nativeScale = 'percent'` if another script writes 0–100 values |
| Location bar misplaced | Does your server move the minimap? Adjust `Config.Location.minimap`, or move it with **Move HUD** |
| Keys didn't change after editing the config | FiveM keeps keys players have customised. New defaults reach players when they reconnect |
| `/carhudadmin` says no permission | Add the ACE line from [Installation](#installation), or check `Config.Permissions.frameworkGroups` |

Turn on `Config.Debug = true` for extra diagnostic messages in F8 and the server console. It is off by default.

---

## Known limitations

- **RPM:** the game only provides normalised RPM (0–1). They are converted with each profile's `redline`, which you can configure per category and model.
- **Aircraft speed** is horizontal ground speed, not airspeed, and is labelled that way.
- **Lights:** the built-in lights control sets the vehicle's light mode. When the resource stops, lights go back to the game's control (mode 0), which can switch off lights turned on with the HUD. High-beam sync depends on the game.
- **Nitro exhaust flames** are a local effect: only the driver sees them.
- **Cruise control** uses the throttle only. It may not hold the exact speed on very steep slopes, and it never brakes.
- **Height above ground** over water depends on `GetEntityHeightAboveGround`.
- **Minimap position** comes from the game's standard layout. Custom minimap setups need `Config.Location.minimap` set to match.
- **Key changes** made in `/carhudadmin` reach each player when they reconnect, unless they have customised that key.
- **Language** is set for the whole server; there is no per-player language choice.

**Tested so far**
- The code is checked statically: syntax, and every native verified against the FiveM natives database.
- Lua logic is tested in a simulated FiveM environment, for client and server.
- The interface is tested in automated browser tests, including real-frame tests of the synchronised visibility, 6 resolutions and 4 safe zones.
- **In game,** it was used on a Qbox server with `ox_fuel`, including real crash/ejection decisions and the player menu.
- **ESX, QBCore, LegacyFuel and cdn-fuel** are supported through adapters written against those resources' official code and tested in simulation. They have not been tested on a live server yet.

---

## Reporting a bug

Please include:

1. The `vortexlabs_carhud` version (printed in the server console at start) and your FiveM server build.
2. Your framework, fuel, seatbelt and keys resources, and any other HUD you run.
3. Exact steps to reproduce, and the vehicle model.
4. Any error lines from F8 and from the server console, starting with `[vortexlabs_carhud]` or `SCRIPT ERROR`.
5. For ejection issues, the `/carhudcrash` output for the crash.
6. Whether it also happens with `Config.Debug = true` and the other HUDs stopped.

Send it to VortexLabs through the channel where you got the resource.

---

## Credits

Design and development: **VortexLabs**. Third-party licences: [THIRD_PARTY.md](THIRD_PARTY.md).
=======
# vortexlabs_carhud
A clean, modern, and highly optimized vehicle HUD for FiveM developed by **VortexLabs**. Built for high performance, full in-game customization, and maximum compatibility with zero required dependencies.
>>>>>>> 24d49258b93f1e30fc3aea27e73c56c64245224e
