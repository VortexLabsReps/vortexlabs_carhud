-- Ubicación: rumbo con histéresis, calle/zona sin restos, solo cambios y
-- visibilidad compartida con el HUD (misma orden), minimapa y preferencias.
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
F.load(F.SHARED)

local G = CarHud.Geo
F.section('Rumbo (lógica pura)')
F.eq(G.bearing(0), 0, 'GTA 0° = norte')
F.eq(G.bearing(90), 270, 'GTA 90° = oeste (sentido antihorario, como qbx.getCardinalDirection)')
F.eq(G.bearing(270), 90, 'GTA 270° = este')
F.eq(G.sector(10), 0, '10° → N')
F.eq(G.sector(45), 1, '45° → NE')
F.eq(G.sector(350), 0, '350° → N')
F.eq(G.sector(24, 0, 8), 0, 'histéresis: 24° sigue en N (límite 22,5°)')
F.eq(G.sector(31, 0, 8), 1, 'pasado el margen (30,5°): NE')
F.eq(G.sector(20, 1, 8), 1, 'de vuelta a 20°: sigue en NE (sin parpadeo)')
F.eq(G.sector(14, 1, 8), 0, 'a 14°: N')
F.eq(G.sector(337, 0, 8), 0, 'junto a 0°/360°: sin saltos')

F.section('Calle y zona (lógica pura)')
local main, sub = G.place('Vinewood Blvd', 'Downtown Vinewood')
F.ok(main == 'Vinewood Blvd' and sub == 'Downtown Vinewood', 'calle principal y zona debajo')
main, sub = G.place('', 'Pacific Ocean')
F.ok(main == 'Pacific Ocean' and sub == '', 'sin calle (mar): la zona pasa a principal')
main, sub = G.place('  ', 'NULL')
F.ok(main == '' and sub == '', 'sin datos: vacío (no se inventa nada)')
main, sub = G.place('Route 68', 'NULL')
F.ok(main == 'Route 68' and sub == '', 'zona desconocida (NULL): solo la calle')

F.section('Visibilidad compartida con el HUD (un solo mensaje)')
os, io = nil, nil
F.load(F.CLIENT)
F.nuiCall('ready')
F.run(700)
local function vis() return F.lastNui('visible') end
-- Último valor de un campo de la ubicación, venga en 'visible' (al aparecer) o en 'location'.
local function lastField(field)
    for i = #F.nui, 1, -1 do
        local m = F.nui[i]
        if (m.t == 'location' or m.t == 'visible') and m[field] ~= nil then return m[field] end
    end
end
-- Invariantes sobre todos los mensajes enviados: la ubicación nunca decide sola.
local function invariants()
    for _, m in ipairs(F.nui) do
        if m.t == 'location' and m.visible ~= nil then return false, 'mensaje de ubicación con visibilidad propia' end
        if m.t == 'visible' and m.loc == true and m.v ~= true then return false, 'ubicación visible sin HUD' end
    end
    return true
end
local function bothHidden() local m = vis() return m and m.v == false and m.loc == false end
local function bothShown() local m = vis() return m and m.v == true and m.loc == true end

F.ok(not vis() or vis().loc ~= true, 'a pie: oculta aunque el minimapa esté visible')
local car = F.spawn({ model = 'sultan', class = 4, heading = 0 })
F.enter(car, -1)
F.run(1200)
F.ok(bothShown(), 'entrar en un coche: HUD y ubicación en la misma orden')
local m = vis()
F.ok(m.main == 'Vinewood Blvd' and m.sub == 'Downtown Vinewood' and m.sector == 0, 'la orden de mostrar ya lleva calle, zona y rumbo (sin datos del vehículo anterior)')
local safe = F.lastNui('safe')
F.ok(safe and safe.mm and safe.gap == 12, 'envía el rectángulo del minimapa y la separación de 12 px')
local safeIdx, visIdx
for i, n in ipairs(F.nui) do
    if n.t == 'safe' and not safeIdx then safeIdx = i end
    if n.t == 'visible' and n.loc == true and not visIdx then visIdx = i end
end
F.ok(safeIdx and visIdx and safeIdx < visIdx, 'el ancla del minimapa llega antes que la orden de mostrar')
F.near(safe.mm.l, 0, 1e-6, 'minimapa: borde izquierdo (zona segura 100 %, posX −0,0045 → 0)')
F.near(safe.mm.t, 1 + 0.002 - 0.188888, 1e-6, 'minimapa: borde superior según frontend.xml')
F.near(safe.mm.r, -0.0045 + 0.150 * ((16 / 9) / F.ui.aspect), 1e-6, 'minimapa: ancho según la relación de aspecto')
local count = #F.nuiOf('location')
F.run(3000)
F.eq(#F.nuiOf('location'), count, 'sin cambios no se envía nada (ni calle ni rumbo)')
F.place.street, F.place.zone, F.place.zoneLabel = '', 'OCEANA', 'Pacific Ocean'
F.run(600)
F.ok(lastField('main') == 'Pacific Ocean' and lastField('sub') == '', 'en el mar: zona como principal, sin conservar la calle anterior')
F.place.street, F.place.zone, F.place.zoneLabel = 'Vinewood Blvd', 'DOWNVW', 'Downtown Vinewood'
F.vehicles[car].heading = 360 - 24
F.run(300)
F.eq(lastField('sector'), 0, 'rumbo 24°: sigue en N')
F.vehicles[car].heading = 360 - 35
F.run(300)
F.eq(lastField('sector'), 1, 'rumbo 35°: NE')
F.vehicles[car].heading = 360 - 21
F.run(300)
F.eq(lastField('sector'), 1, 'vuelta a 21°: sigue en NE (histéresis)')

local before = #F.nuiOf('visible')
F.pedState.exiting = true
F.run(Config.Rates.fast + 20)
F.ok(bothHidden(), 'al empezar a salir (CTaskExitVehicle): HUD y ubicación ocultos en la misma orden')
F.eq(#F.nuiOf('visible'), before + 1, 'una sola orden para ocultarlo todo')
F.pedState.exiting = false
F.exitVehicle()
F.run(300)
F.ok(bothHidden(), 'fuera del vehículo: todo oculto')
local n = #F.nuiOf('visible')
F.run(2000)
F.ok(bothHidden() and #F.nuiOf('visible') == n, 'a pie sigue oculto, sin órdenes sueltas')

local car2 = F.spawn({ model = 'adder', class = 7, heading = 90 })
F.enter(car2, -1)
F.run(1200)
F.ok(bothShown(), 'cambiar a otro vehículo: visible de nuevo')
F.eq(vis().sector, 6, 'con el rumbo del nuevo vehículo ya en la orden (GTA 90° = oeste)')

-- Entrar y salir repetidamente, con tiempos distintos (también muy cortos).
local okCycles = true
for i, stay in ipairs({ 40, 90, 160, 300, 60, 520, 30, 200, 75, 1000 }) do
    F.exitVehicle()
    F.run(Config.Rates.fast + 20) -- una vuelta del bucle del HUD
    if not bothHidden() then okCycles = false end
    F.enter(i % 2 == 0 and car or car2, -1)
    F.run(stay)
    local last = vis()
    if last.v ~= last.loc then okCycles = false end
end
F.ok(okCycles, "10 entradas y salidas seguidas: HUD y ubicación siempre en el mismo estado")
F.run(1200)
F.ok(bothShown(), 'tras los ciclos, dentro del vehículo: los dos visibles')
F.exitVehicle()
F.run(Config.Rates.fast + 20)
F.ok(bothHidden(), 'tras los ciclos, fuera: los dos ocultos')
F.run(400)

local bmx = F.spawn({ model = 'bmx', class = 13, kind = { bicycle = true } })
F.enter(bmx, -1)
F.run(1500)
F.ok(not vis().v and not vis().loc, 'bicicleta: nunca se muestra')
F.exitVehicle() F.run(400)
local plane = F.spawn({ model = 'luxor', class = 16, kind = { plane = true }, type = 'plane' })
F.enter(plane, -1)
F.run(1200)
F.ok(bothShown(), 'avión (compatible con el HUD): visible')
F.exitVehicle() F.run(400)

F.enter(car, -1)
F.run(1200)
F.ui.radarHidden = true
F.run(400)
F.ok(vis().v == true and vis().loc == false, 'minimapa oculto: solo se oculta la ubicación (el HUD sigue)')
F.ui.radarHidden = false
F.place.bigmap = true
F.run(400)
F.ok(vis().v == true and vis().loc == false, 'mapa ampliado: ubicación oculta')
F.place.bigmap = false
F.run(400)
F.ok(bothShown(), 'vuelve con el minimapa normal')
F.ui.pause = true
F.run(400)
F.ok(bothHidden(), 'menú de pausa: todo oculto en la misma orden')
F.ui.pause = false
F.run(600)
F.ok(bothShown(), 'al salir de la pausa vuelven juntos')
F.ui.safe = 0.9
F.run(2200)
safe = F.lastNui('safe')
F.near(safe.mm.l, 0.05 - 0.0045, 1e-6, 'zona segura 90 %: el minimapa se desplaza con ella')
local inv, why = invariants()
F.ok(inv, 'en toda la prueba la ubicación nunca tuvo visibilidad propia ni apareció sin HUD' .. (why and (' (' .. why .. ')') or ''))

F.section('Preferencias')
local defaults = CarHud.Settings.defaults()
local rules = CarHud.Settings.rules()
F.ok(defaults.location.scale == 1.02 and defaults.location.x == nil and defaults.location.enabled == true, 'predeterminado: tamaño 102 % y sin posición guardada (usa Config.Location.default)')
F.near(rules.locationDefault.x, 20 / 1080, 1e-9, 'predeterminado: 20 px a la derecha del ancla (1080p)')
F.near(rules.locationDefault.y, -37 / 1080, 1e-9, 'predeterminado: 37 px por encima de la posición base')
F.eq(rules.locationDefault.scale, 1.02, 'la NUI recibe el tamaño predeterminado para «Restaurar tamaño»')
F.nuiCall('save', { settings = { location = { enabled = false, scale = 1.3, x = 0.05, y = -0.02 } } })
F.run(600)
F.ok(vis().v == true and vis().loc == false, 'el jugador puede desactivarla (el HUD sigue)')
local saved = json.decode(F.kvp['vortexlabs_carhud:settings'])
F.ok(saved.location.enabled == false and saved.location.scale == 1.3 and saved.location.x == 0.05, 'escala y posición guardadas (KVP)')
F.nuiCall('save', { settings = { location = { enabled = true, scale = 9, x = 5, y = -5 } } })
saved = json.decode(F.kvp['vortexlabs_carhud:settings'])
F.ok(saved.location.scale == Config.Player.scaleMax and saved.location.x == 0.6 and saved.location.y == -0.6, 'valores fuera de límites: corregidos')
F.run(600)
F.ok(bothShown(), 'reactivada')
Config.Location.enabled = false
F.run(600)
F.ok(vis().v == true and vis().loc == false, 'el servidor puede desactivarla para todos')
Config.Location.enabled = true

F.finish()
