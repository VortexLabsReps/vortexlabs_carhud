-- Simulación del cliente completo con natives simuladas (dev/fivem.lua).
-- Comprueba flujos y contratos; no sustituye a las pruebas dentro del juego.
local F = dofile(FD_ROOT .. '/dev/fivem.lua')

local function lastSlowField(field)
    for i = #F.nui, 1, -1 do
        local m = F.nui[i]
        if m.t == 's' and m[field] ~= nil then return m[field] end
    end
end
local function lastTT(field)
    for i = #F.nui, 1, -1 do
        local m = F.nui[i]
        if m.t == 's' and m.tt and m.tt[field] ~= nil then return m.tt[field] end
    end
end
local function lastFast(field)
    for i = #F.nui, 1, -1 do
        local m = F.nui[i]
        if m.t == 'f' and m[field] ~= nil then return m[field] end
    end
end
local function serverEvents(name)
    local n = 0
    for _, e in ipairs(F.serverEvents) do if e.name == name then n = n + 1 end end
    return n
end
local function lastNotice()
    local m = F.lastNui('notice')
    return m and (m.key or m.text)
end
local function tap(command) F.command('+' .. command) F.run(50) F.command('-' .. command) F.run(300) end

------------------------------------------------------------------------------
F.section('Arranque dentro de un vehículo (reinicio del recurso)')
local car = F.spawn({ model = 'sultan', class = 4, speed = 0, plate = 'CAR 1' })
F.enter(car, -1) F.run(700)
F.load(F.SHARED)
-- El cliente de FiveM no tiene las librerías os ni io (el servidor sí).
os, io = nil, nil
F.load(F.CLIENT)
F.run(400)
F.eq(#F.nui, 0, 'sin mensajes antes de que la NUI esté lista')
F.nuiCall('ready')
F.eq(F.nui[1].t, 'init', 'init al estar lista la NUI')
F.ok(F.nui[1].settings and F.nui[1].settings.unit == 'kmh', 'init lleva preferencias validadas')
F.ok(F.lastNui('profile') and F.lastNui('profile').profile.category == 'car', 'perfil de coche enviado tras ready')
F.run(300)
F.ok(F.lastNui('visible').v == true, 'HUD visible dentro del coche')
F.eq(CarHud.Framework.name, 'standalone', 'standalone sin framework')
F.eq(CarHud.Fuel.active, 'native', 'combustible nativo sin proveedor')
F.eq(CarHud.Seatbelt.mode, 'own', 'cinturón propio sin cinturón externo')
F.eq(lastSlowField('fuel'), 100, 'combustible nativo: 65 L de 65 → 100 %')
F.ok(F.keymaps['fcarhud_seatbelt'] and F.keymaps['+fcarhud_lights'] and F.keymaps['fcarhud_cruise'] and F.keymaps['+fcarhud_nitro'], 'teclas reasignables registradas')

------------------------------------------------------------------------------
F.ok(CarHud.Perf ~= nil, 'carga sin la librería os (como el cliente real)')
F.command('carhud', 0, { 'perf', '3' })
F.run(3200)
F.ok(F.prints[#F.prints]:find('resmon') ~= nil, '/carhud perf sin reloj de alta resolución: informa y remite a resmon')

F.section('Telemetría independiente')
local v = F.vehicles[car]
v.speed, v.throttle, v.rpm, v.gear = 30.0, 0.0, 0.9, 2
F.run(200)
F.eq(lastFast('s'), 30, 'velocidad real')
F.eq(lastFast('p'), 0, 'sin pedal aunque haya velocidad')
F.eq(lastFast('r'), 0.9, 'RPM reales')
F.eq(lastFast('g'), 2, 'marcha real')
v.speed, v.throttle, v.rpm, v.gear = 0.0, 1.0, 0.35, 1
F.run(200)
F.eq(lastFast('p'), 1, 'pedal a fondo parado (el pedal no deriva de la velocidad)')
F.eq(lastFast('s'), 0, 'vehículo detenido')
v.gear, v.throttle, v.speed = 0, -0.6, 3.0
F.run(200)
F.eq(lastFast('g'), 0, 'marcha atrás → 0 (la NUI muestra R)')
F.eq(lastFast('p'), 0.6, 'pedal en marcha atrás')
v.gear, v.throttle = 3, -0.7
F.run(200)
F.eq(lastFast('p'), 0, 'freno con marcha adelante no se muestra como acelerador')
v.engineOn = false
F.run(400)
F.eq(lastFast('r'), 0, 'motor apagado → RPM 0')
F.eq(lastSlowField('run'), false, 'estado del motor apagado')
v.engineOn = true
v.speed, v.throttle, v.rpm, v.gear = 20.0, 0.4, 0.5, 3
F.run(300)
local before = #F.nuiOf('f')
F.run(1000)
F.eq(#F.nuiOf('f'), before, 'sin mensajes NUI cuando nada cambia')
v.speed = 20.02
F.run(200)
F.eq(#F.nuiOf('f'), before, 'variaciones bajo el umbral no se envían')

------------------------------------------------------------------------------
F.section('Visibilidad')
F.ui.pause = true
F.run(300)
F.eq(F.lastNui('visible').v, false, 'menú de pausa oculta el HUD')
F.ui.pause = false
F.run(300)
F.eq(F.lastNui('visible').v, true, 'al salir de pausa vuelve')
F.ok((F.hiddenComponents or 0) > 0, 'componentes nativos solapados ocultos mientras se ve el HUD')
F.invoking = 'cinematica'
F.ownExports.SetHudVisible(false)
F.run(300)
F.eq(F.lastNui('visible').v, false, 'otro recurso puede ocultar el HUD')
F.stopResource('cinematica')
F.run(300)
F.eq(F.lastNui('visible').v, true, 'la ocultación se libera si ese recurso se detiene')

------------------------------------------------------------------------------
F.section('Cinturón propio')
F.eq(F.pedState.flags[32], false, 'expulsión nativa desactivada dentro (solo decide la mecánica propia)')
v.speed = 0
F.run(300)
F.eq(lastTT('belt'), 'off', 'desabrochado y parado: gris, sin aviso')
v.speed = 50 / 3.6
F.run(400)
F.eq(lastTT('belt'), 'warn', 'desabrochado circulando: aviso rojo')
F.eq(lastSlowField('beltWarn'), true, 'aviso de cinturón en la franja')
F.eq(F.lastNui('sound').name, 'belt_warn', 'sonido de aviso')
local warns = #F.nuiOf('sound')
F.run(2000)
F.eq(#F.nuiOf('sound'), warns, 'el aviso sonoro respeta el intervalo')
F.command('fcarhud_seatbelt')
F.run(300)
F.eq(LocalPlayer.state.seatbelt, true, 'abrochado: statebag seatbelt')
F.eq(F.lastNui('sound').name, 'belt_on', 'sonido de abrochar')
F.eq(lastTT('belt'), 'on', 'testigo abrochado')
F.eq(F.ownExports.IsSeatbeltOn(), true, 'export IsSeatbeltOn')
F.run(50)
F.ok(F.disabled[75] == true, 'tecla de salir bloqueada mientras está abrochado')
F.input.just[75] = true
F.run(20)
F.input.just[75] = nil
F.eq(lastNotice(), 'notice.exitLocked', 'aviso al intentar salir abrochado')
F.command('fcarhud_seatbelt')
F.run(50)
F.ok(F.disabled[75] ~= true, 'al desabrochar no queda ningún control bloqueado')

F.section('Expulsión por accidente')
v.speed, v.vel, v.collided = 110 / 3.6, { x = 0, y = 110 / 3.6, z = 0 }, false
F.run(100)
v.speed, v.vel, v.collided = 4 / 3.6, { x = 0, y = 4 / 3.6, z = 0 }, true
F.run(100)
F.ok(F.pedState.coords.y > 2, 'aparece fuera del vehículo, por delante (dirección de la inercia)')
F.eq(F.pedVehicle, 0, 'sin cinturón a 110 km/h: expulsado')
F.ok(F.pedState.ragdoll and F.pedState.damage > 0, 'ragdoll y daño aplicados')
F.run(400)
F.eq(F.pedState.flags[32], true, 'flag de expulsión nativa restaurado al salir')
F.eq(F.lastNui('visible').v, false, 'HUD oculto al salir del vehículo')
v.collided = false

------------------------------------------------------------------------------
F.section('Luces e intermitentes')
F.pedState.ragdoll = false
v.speed = 0
F.enter(car, -1) F.run(700)
F.run(400)
F.eq(LocalPlayer.state.seatbelt, false, 'el cinturón se restablece al entrar')
F.run(50)
F.ok(F.disabled[74] == true, 'tecla nativa de luces desactivada (sin doble alternancia)')
F.eq(lastTT('lights'), 'off', 'luces apagadas')
tap('fcarhud_lights')
F.eq(v.lightsOn, true, 'pulsación corta enciende')
F.eq(lastTT('lights'), 'low', 'testigo: cortas')
F.command('+fcarhud_lights')
F.run(500)
F.command('-fcarhud_lights')
F.run(300)
F.eq(v.high, true, 'mantener: largas')
F.eq(lastTT('lights'), 'high', 'testigo: largas')
F.ok(v.lightsOn, 'soltar tras mantener no apaga las luces')
tap('fcarhud_lights')
F.ok(not v.lightsOn and not v.high, 'pulsación corta apaga todo')
F.eq(lastTT('lights'), 'off', 'testigo: apagadas')
F.command('fcarhud_left') F.run(300)
F.eq(v.ind, 1, 'intermitente izquierdo')
F.eq(lastTT('ind'), 1, 'testigo izquierdo')
F.command('fcarhud_hazard') F.run(300)
F.eq(v.ind, 3, 'emergencia: ambos')
F.command('fcarhud_right') F.run(300)
F.eq(v.ind, 2, 'derecho desde emergencia')
F.command('fcarhud_right') F.run(300)
F.eq(v.ind, 0, 'derecho de nuevo: apagado')
F.command('fcarhud_hazard') F.run(300)
F.command('fcarhud_hazard') F.run(300)
F.eq(v.ind, 0, 'emergencia on/off')

------------------------------------------------------------------------------
F.section('Control de crucero')
v.speed, v.gear = 20 / 3.6, 2
F.command('fcarhud_cruise')
F.run(100)
F.eq(CarHud.Cruise.target, 0, 'por debajo de la velocidad mínima no se activa')
F.eq(lastNotice(), 'notice.cruiseMin', 'aviso de velocidad mínima')
v.speed = 72 / 3.6
F.command('fcarhud_cruise')
F.run(50)
F.near(CarHud.Cruise.target, 20, 1e-6, 'activado a la velocidad actual')
F.near(lastTT('cruise') or 0, 20, 0.01, 'testigo y marca del arco con la velocidad objetivo')
v.speed = 18
F.run(20)
F.ok((F.injected[71] or 0) > 0.3, 'por debajo del objetivo dosifica acelerador')
v.speed = 21
F.run(20)
F.ok(F.injected[71] == nil, 'por encima del objetivo no acelera (no frena ni limita)')
F.command('fcarhud_cruise_up')
F.run(50)
F.near(CarHud.Cruise.target * 3.6, 75, 1e-6, "ajuste: de 72 km/h al siguiente múltiplo de 5 (75)")
F.input.pressed[72] = true
F.run(20)
F.input.pressed[72] = nil
F.eq(CarHud.Cruise.target, 0, 'frenar cancela')
F.eq(lastNotice(), 'notice.cruiseOff', 'aviso de cancelación')
F.command('fcarhud_cruise')
F.run(20)
F.moveSeat(car, 0)
F.run(400)
F.eq(CarHud.Cruise.target, 0, 'cambiar al asiento del pasajero cancela')
F.ok(F.disabled[74] ~= true, 'pasajero: la tecla nativa de luces vuelve a funcionar')
local indBefore = v.ind
F.command('fcarhud_left') F.run(100)
F.eq(v.ind, indBefore, 'pasajero: sin control de intermitentes')
F.command('fcarhud_cruise') F.run(100)
F.eq(CarHud.Cruise.target, 0, 'pasajero: sin crucero')
F.eq(F.lastNui('visible').v, true, 'pasajero: ve el HUD (showForPassengers)')
F.moveSeat(car, -1)
F.run(400)

------------------------------------------------------------------------------
F.section('Motor y llaves')
F.command('fcarhud_engine') F.run(100)
F.eq(v.engineOn, false, 'apagar motor')
F.resources['qbx_vehiclekeys'] = 'started'
F.extExports['qbx_vehiclekeys'] = { HasKeys = function() return false end }
F.command('fcarhud_engine') F.run(100)
F.eq(v.engineOn, false, 'sin llaves no arranca')
F.eq(lastNotice(), 'notice.noKeys', 'aviso de llaves')
F.extExports['qbx_vehiclekeys'].HasKeys = function() return true end
F.command('fcarhud_engine') F.run(100)
F.eq(v.engineOn, true, 'con llaves arranca')
F.extExports['qbx_vehiclekeys'].HasKeys = function() error('recurso reiniciándose') end
F.command('fcarhud_engine') F.run(100)
F.command('fcarhud_engine') F.run(100)
F.eq(v.engineOn, true, 'error del sistema de llaves: no rompe el recurso')
F.ownExports.SetEngineAuthorizer(function() return false end)
F.command('fcarhud_engine') F.run(100)
F.command('fcarhud_engine') F.run(100)
F.eq(v.engineOn, false, 'autorizador registrado por export bloquea el arranque')
F.ownExports.SetEngineAuthorizer(nil)
F.resources['qbx_vehiclekeys'] = nil
F.command('fcarhud_engine') F.run(100)
F.eq(v.engineOn, true, 'sin sistema de llaves: el conductor arranca')

------------------------------------------------------------------------------
F.section('Turbo eliminado')
v.turbo, v.turboP = true, 0.6
F.run(400)
local turboSent = false
for _, m in ipairs(F.nui) do if m.turbo ~= nil or m.tb ~= nil then turboSent = true end end
F.ok(not turboSent, 'no se lee ni se envía el turbo aunque esté montado')
F.ok(F.lastNui('profile').profile.turbo == nil, 'el perfil ya no incluye turbo')
v.turbo = false

------------------------------------------------------------------------------
F.section('Nitro (cliente)')
F.run(300)
F.eq(lastSlowField("nos"), false, "sin equipar: el módulo no aparece")
F.command('+fcarhud_nitro') F.run(50) F.command('-fcarhud_nitro')
F.eq(serverEvents('vortexlabs_carhud:nitro:start'), 0, 'sin equipar no pide activación')
Entity(car).state:set('fcarhud_nitro', { amt = 50, cap = 100, on = false }, true)
F.run(300)
local nos = lastSlowField('nos')
F.ok(type(nos) == 'table' and nos.amt == 50 and nos.cap == 100 and nos.on == false, 'equipado: carga leída del statebag del servidor')
F.command('+fcarhud_nitro')
F.run(50)
F.eq(serverEvents('vortexlabs_carhud:nitro:start'), 1, 'mantener tecla pide activación al servidor')
F.eq(v.power, 0, 'sin confirmación del servidor no hay efecto')
Entity(car).state:set('fcarhud_nitro', { amt = 50, cap = 100, on = true }, true)
v.throttle = 0.9
F.run(100)
F.eq(v.power, Config.Nitro.power, 'confirmado y acelerando: potencia aplicada')
F.ok(F.particles > 0, 'llamaradas en el escape')
F.run(300)
F.eq(lastSlowField('nos').on, true, 'activo: el icono se ilumina')
F.command('-fcarhud_nitro')
F.run(50)
F.eq(serverEvents('vortexlabs_carhud:nitro:stop'), 1, 'soltar pide parar')
Entity(car).state:set('fcarhud_nitro', { amt = 38, cap = 100, on = false }, true)
v.power = 0
F.run(200)
F.eq(v.power, 0, 'desactivado: el efecto desaparece')
Entity(car).state:set('fcarhud_nitro', { amt = 0, cap = 100, on = false }, true)
F.run(300)
F.eq(lastSlowField('nos').amt, 0, 'agotado: módulo visible vacío')
local starts = serverEvents('vortexlabs_carhud:nitro:start')
F.command('+fcarhud_nitro') F.run(50) F.command('-fcarhud_nitro')
F.eq(serverEvents('vortexlabs_carhud:nitro:start'), starts, 'agotado: no pide activación')
Config.Features.nitro = false
F.exitVehicle() F.run(400) F.enter(car, -1) F.run(700)
F.eq(lastSlowField("nos"), false, "nitro desactivado en config: no se muestra")
Config.Features.nitro = true

------------------------------------------------------------------------------
F.section('Combustible: proveedores')
F.exitVehicle() F.run(400) F.enter(car, -1) F.run(700)
F.resources['ox_fuel'] = 'started'
F.startResource('ox_fuel')
F.eq(CarHud.Fuel.active, 'ox_fuel', 'ox_fuel detectado automáticamente')
F.run(300)
F.eq(lastSlowField('fuel'), -1, 'ox_fuel sin statebag: "sin dato" (no 0)')
Entity(car).state.fuel = 0
F.run(300)
F.eq(lastSlowField('fuel'), 0, 'ox_fuel con 0: depósito vacío')
Entity(car).state.fuel = 42.37
F.run(300)
F.eq(lastSlowField('fuel'), 42.4, 'ox_fuel 0–100')
F.stopResource('ox_fuel')
v.fuelLevel = 30
F.run(300)
F.eq(CarHud.Fuel.active, 'native', 'proveedor detenido → recuperación nativa')
F.eq(lastSlowField('fuel'), 30, 'recuperación nativa en porcentaje (el proveedor escribía 0–100)')
F.extExports['LegacyFuel'] = { GetFuel = function() return 0.0 end }
F.startResource('LegacyFuel')
F.eq(CarHud.Fuel.active, 'LegacyFuel', 'LegacyFuel detectado')
F.run(300)
F.eq(lastSlowField('fuel'), -1, 'LegacyFuel sin decorador: sin dato (GetFuel devolvería 0)')
v.decors['_FUEL_LEVEL'] = 0
F.run(300)
F.eq(lastSlowField('fuel'), 0, 'LegacyFuel con decorador a 0: vacío')
F.extExports['LegacyFuel'].GetFuel = function() return 77.0 end
F.run(300)
F.eq(lastSlowField('fuel'), 77, 'LegacyFuel lectura normal')
F.extExports['cdn-fuel'] = { GetFuel = function() return 12.5 end }
F.startResource('cdn-fuel')
F.eq(CarHud.Fuel.active, 'cdn-fuel', 'cdn-fuel tiene prioridad sobre LegacyFuel en auto')
F.run(300)
F.eq(lastSlowField('fuel'), 12.5, 'cdn-fuel lectura')
F.extExports['cdn-fuel'].GetFuel = function() error('reiniciando') end
F.run(2000)
F.eq(CarHud.Fuel.active, 'native', 'export que falla repetidamente → nativo, sin errores continuos')
F.stopResource('cdn-fuel') F.stopResource('LegacyFuel')
Config.Fuel.provider = 'ox_fuel'
CarHud.Fuel.select()
F.eq(CarHud.Fuel.active, 'native', 'proveedor explícito no iniciado → nativo')
Config.Fuel.provider = 'auto'
CarHud.Fuel.fallbackScale = nil
v.usesFuel = false
F.run(300)
F.eq(lastSlowField('fuel'), false, 'vehículo sin combustible (eléctrico/sin depósito): módulo oculto')
v.usesFuel = true
v.fuelLevel, v.tank = 0, 65
F.run(300)
F.eq(lastSlowField('fuel'), 0, 'nativo: depósito vacío = 0')
F.ok(#F.prints > 0, 'aviso único de proveedor no disponible')

------------------------------------------------------------------------------
F.section('Avisos y vehículo destruido')
v.engineHealth = 250
F.run(300)
F.eq(lastSlowField('eng'), 25, 'motor 25 %')
v.dead = true
F.run(300)
F.eq(lastSlowField('eng'), 0, 'destruido: motor 0')
F.eq(lastSlowField('run'), false, 'destruido: motor parado')
F.command('fcarhud_cruise') F.run(50)
F.eq(CarHud.Cruise.target, 0, 'destruido: sin crucero')
v.dead, v.engineHealth = false, 1000

------------------------------------------------------------------------------
F.section('Bicicleta: exclusión total')
local bmx = F.spawn({ model = 'bmx', class = 13, kind = { bicycle = true }, speed = 8 })
F.exitVehicle() F.run(400)
local nuiCount = #F.nui
local evCount = #F.serverEvents
F.enter(bmx, -1) F.run(700)
F.run(1000)
F.eq(F.lastNui('visible').v, false, 'bicicleta: HUD oculto')
for _, cmd in ipairs({ 'fcarhud_seatbelt', 'fcarhud_cruise', 'fcarhud_engine', 'fcarhud_left', 'fcarhud_hazard' }) do F.command(cmd) end
tap('fcarhud_lights')
F.command('+fcarhud_nitro') F.run(100) F.command('-fcarhud_nitro')
F.run(300)
local b = F.vehicles[bmx]
F.ok(LocalPlayer.state.seatbelt ~= true and CarHud.Cruise.target == 0 and b.engineOn and b.ind == 0 and not b.lightsOn, 'bicicleta: ninguna función se activa')
F.eq(#F.serverEvents, evCount, 'bicicleta: ni siquiera se consulta el nitro al servidor')
local sent = 0
for i = nuiCount + 1, #F.nui do if F.nui[i].t == 'f' or F.nui[i].t == 's' then sent = sent + 1 end end
F.eq(sent, 0, 'bicicleta: no se lee ni envía telemetría')
F.ok(F.disabled[74] ~= true and F.disabled[75] ~= true, 'bicicleta: ningún control desactivado')
Config.Models['bmx'] = { category = 'motorcycle' }
CarHud.Profiles.indexModels(GetHashKey)
F.exitVehicle() F.run(400) F.enter(bmx, -1) F.run(700)
F.eq(F.lastNui('profile').profile.category, 'motorcycle', 'excepción por modelo: e-bike personalizada con HUD de moto')
Config.Models['bmx'] = nil
CarHud.Profiles.indexModels(GetHashKey)

------------------------------------------------------------------------------
F.section('Moto, lancha, avión y helicóptero')
local bati = F.spawn({ model = 'bati', class = 8, kind = { bike = true } })
F.exitVehicle() F.run(400) F.enter(bati, -1) F.run(700)
local pm = F.lastNui('profile').profile
F.ok(pm.category == 'motorcycle' and pm.compact and pm.telltales.belt == false and pm.telltales.lights, 'moto: compacta, sin cinturón, con luces')
local soundsBefore = #F.nuiOf('sound')
F.command('fcarhud_seatbelt') F.run(100)
F.ok(LocalPlayer.state.seatbelt ~= true and #F.nuiOf('sound') == soundsBefore, 'moto: la tecla de cinturón no hace nada')
F.vehicles[bati].speed = 60 / 3.6
F.run(400)
F.eq(lastSlowField('beltWarn'), false, 'moto: sin aviso de cinturón')

local boatH = F.spawn({ model = 'speeder', class = 14, kind = { boat = true }, type = 'boat' })
F.exitVehicle() F.run(400) F.enter(boatH, -1) F.run(700)
local pb = F.lastNui('profile').profile
F.ok(pb.category == 'boat' and not pb.gear and not pb.nitro and pb.rpm and pb.telltales.cruise == false, 'lancha: sin marcha, nitro ni crucero')
F.vehicles[boatH].throttle = -0.5
F.vehicles[boatH].speed = 5
F.run(300)
F.eq(lastFast('p'), 0.5, 'lancha: empuje atrás cuenta como potencia')
local fastBoat = F.lastNui('f')
F.ok(fastBoat.g == nil, 'lancha: no se envía marcha')
F.command('fcarhud_cruise') F.run(50)
F.eq(CarHud.Cruise.target, 0, 'lancha: sin crucero')

local plane = F.spawn({ model = 'luxor', class = 16, kind = { plane = true }, type = 'plane', speed = 70, vel = { x = 30, y = 40, z = 5 }, coords = { x = 0, y = 0, z = 812.4 }, agl = 300 })
F.exitVehicle() F.run(400) F.enter(plane, -1) F.run(700)
local pp = F.lastNui('profile').profile
F.ok(pp.aircraft == 'plane' and not pp.gear and not pp.rpm and not pp.nitro and pp.telltales.cruise == false, 'avión: variante de aeronave sin datos ficticios')
F.eq(lastFast('s'), 50, 'avión: velocidad respecto al suelo (componente horizontal)')
F.eq(lastFast('m'), 812, 'avión: altitud sobre el nivel del mar')
F.eq(lastFast('a'), 300, 'avión: altura sobre el suelo')
F.eq(lastFast('v'), nil, 'avión: sin velocidad vertical')
F.command('fcarhud_cruise') F.run(50)
F.eq(CarHud.Cruise.target, 0, 'avión: el crucero no actúa como piloto automático')

local heli = F.spawn({ model = 'buzzard', class = 15, kind = { heli = true }, type = 'heli', vel = { x = 0, y = 10, z = -2.5 }, speed = 10.3, agl = 42 })
F.exitVehicle() F.run(400) F.enter(heli, -1) F.run(700)
F.eq(lastFast('a'), 42, 'helicóptero: altura sobre el suelo')
F.eq(lastFast('v'), -2.5, 'helicóptero: velocidad vertical')

------------------------------------------------------------------------------
F.section('Cinturón externo (qbx_seatbelt)')
F.exitVehicle() F.run(400)
F.startResource('qbx_seatbelt')
F.run(50)
F.eq(CarHud.Seatbelt.mode, 'external', 'qbx_seatbelt iniciado → modo externo')
F.enter(car, -1) F.run(700)
LocalPlayer.state.seatbelt = true
F.run(300)
F.eq(lastTT('belt'), 'on', 'refleja el statebag del recurso externo')
F.ok(F.disabled[75] ~= true, 'modo externo: sin bloqueo propio de salida')
LocalPlayer.state.seatbelt = false
F.stopResource('qbx_seatbelt')
F.run(50)
F.eq(CarHud.Seatbelt.mode, 'own', 'qbx_seatbelt detenido → vuelve la mecánica propia')

------------------------------------------------------------------------------
F.section('Framework (detección y recuperación)')
F.resources['qb-core'] = 'started'
F.startResource('qbx_core')
F.eq(CarHud.Framework.name, 'qbox', 'Qbox detectado antes que qb-core (aunque lo proporcione)')
LocalPlayer.state.isLoggedIn = false
F.run(300)
F.eq(F.lastNui('visible').v, false, 'personaje sin cargar: HUD oculto')
LocalPlayer.state.isLoggedIn = true
F.run(300)
F.eq(F.lastNui('visible').v, true, 'personaje cargado: HUD visible')
F.stopResource('qbx_core')
F.run(300)
F.eq(F.lastNui('visible').v, true, 'framework detenido: sin errores, HUD sigue')
F.startResource('qb-core')
F.eq(CarHud.Framework.name, 'qbcore', 'QBCore detectado')
F.resources['qb-core'] = nil
F.startResource('es_extended')
F.eq(CarHud.Framework.name, 'esx', 'ESX detectado')
F.resources['es_extended'] = nil
CarHud.Framework.refresh()
F.eq(CarHud.Framework.name, 'standalone', 'sin framework → standalone')

------------------------------------------------------------------------------
F.section('Ajustes del jugador')
F.command('carhud')
F.ok(F.focus[1] == true and F.lastNui('openSettings') ~= nil, '/carhud abre el menú y toma el foco')
F.nuiCall('save', { settings = { unit = 'mph', accent = '#ff7a59', volume = 4, cluster = { scale = 0.2, x = 0.9, y = 0.85 } } })
local saved = F.lastNui('settings').settings
F.ok(saved.unit == 'mph' and saved.accent == '#FF7A59' and saved.volume == 1 and saved.cluster.scale == Config.Player.scaleMin, 'cambios validados y devueltos a la NUI')
F.ok(F.kvp['vortexlabs_carhud:settings'] ~= nil, 'guardado local en KVP (sin SQL)')
F.ui.pause = true
F.run(300)
F.ok(F.focus[1] == false, 'abrir la pausa cierra el menú y libera el foco')
F.ui.pause = false
F.command('carhud')
F.nuiCall('opened')
F.run(2000)
F.ok(F.focus[1] == true, 'con la interfaz confirmando, el menú sigue abierto')
F.nuiCall('close', {})
F.ok(F.focus[1] == false, 'cerrar libera el foco')
F.command('carhud')
F.run(2000)
F.ok(F.focus[1] == false, 'si la interfaz no confirma la apertura, se libera el foco')
F.nuiCall('reset')
F.eq(F.lastNui('settings').settings.unit, 'kmh', 'restaurar configuración')
F.eq(F.kvp['vortexlabs_carhud:settings'], nil, 'restaurar borra la KVP')
F.kvp['vortexlabs_carhud:settings'] = '{"unit":"mph","accent":"#zzz","modules":{"rpm":false},"volume":-2'
dofile(FD_ROOT .. '/client/settings.lua')
F.eq(CarHud.State.settings.unit, 'kmh', 'KVP corrupta: se ignora sin errores')

------------------------------------------------------------------------------
F.section('Parada del recurso dentro del vehículo')
F.command('fcarhud_seatbelt') F.run(100)
tap('fcarhud_lights')
F.eq(v.lightsMode, 2, 'luces forzadas por el control propio')
F.stopResource('vortexlabs_carhud')
F.eq(v.lightsMode, 0, 'al parar: el control de luces vuelve al juego')
F.eq(F.pedState.flags[32], true, 'al parar: flag de expulsión restaurado')
F.eq(LocalPlayer.state.seatbelt, false, 'al parar: statebag del cinturón a false')
F.ok(F.focus[1] == false, 'al parar: sin foco de NUI')

F.finish()
