-- Pruebas de la lógica compartida: perfiles, matriz de funciones, escalas,
-- pedal, detector de choques, validación de ajustes y contabilidad del nitro.
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
F.load(F.SHARED)
dofile(FD_ROOT .. '/server/nitro_store.lua')

local P = CarHud.Profiles
local U = CarHud.Util

F.section('Categorías')
F.eq(P.categoryFrom({ class = 7 }), 'car', 'clase 7 → coche')
F.eq(P.categoryFrom({ class = 8, bike = true }), 'motorcycle', 'moto')
F.eq(P.categoryFrom({ class = 9, quad = true }), 'motorcycle', 'quad → perfil de moto (sin cinturón)')
F.eq(P.categoryFrom({ class = 13, bicycle = true }), 'bicycle', 'bicicleta')
F.eq(P.categoryFrom({ class = 13 }), 'bicycle', 'clase 13 sin bandera → bicicleta')
F.eq(P.categoryFrom({ class = 8, bicycle = true }), 'bicycle', 'bandera de bici prevalece sobre la clase')
F.eq(P.categoryFrom({ class = 14, boat = true }), 'boat', 'lancha')
F.eq(P.categoryFrom({ class = 14, jetski = true }), 'boat', 'moto acuática → embarcación')
F.eq(P.categoryFrom({ class = 15, heli = true }), 'heli', 'helicóptero')
F.eq(P.categoryFrom({ class = 16, plane = true }), 'plane', 'avión')
F.eq(P.categoryFrom({ class = 21 }), 'train', 'tren')
F.eq(P.categoryFrom({ class = 13, bicycle = true, override = 'motorcycle' }), 'motorcycle', 'excepción por modelo: e-bike como moto')
F.eq(P.categoryFrom({ class = 7, override = 'bicycle' }), 'bicycle', 'excepción por modelo: bici personalizada')

F.section('Matriz de funciones')
local car = P.build('car')
F.ok(car.hud and car.gear and car.rpm and car.throttle and car.fuel and car.engine and car.nitro, 'coche: telemetría completa')
F.ok(car.seatbelt and car.lights and car.indicators and car.cruise and car.engineToggle, 'coche: funciones propias')
local moto = P.build('motorcycle')
F.ok(moto.hud and not moto.seatbelt and moto.compact, 'moto: compacta y sin cinturón')
F.ok(moto.nitro, 'moto: nitro sujeto a equipamiento')
F.ok(car.turbo == nil and moto.turbo == nil, 'el turbo ya no forma parte de ningún perfil')
local boat = P.build('boat')
F.ok(boat.hud and boat.fuel and boat.engine and boat.rpm and boat.throttle, 'lancha: velocidad, combustible, motor y propulsión')
F.ok(not boat.gear and not boat.nitro and not boat.seatbelt and not boat.cruise and not boat.indicators, 'lancha: sin marchas, nitro, cinturón, crucero ni intermitentes')
local plane = P.build('plane')
F.ok(plane.hud and plane.altitudeMsl and plane.altitudeAgl and plane.fuel and plane.engine, 'avión: altitud mar/suelo, combustible, motor')
F.ok(not plane.cruise and not plane.seatbelt and not plane.nitro and not plane.gear and not plane.rpm, 'avión: sin crucero, cinturón, nitro, marchas ni RPM')
local heli = P.build('heli')
F.ok(heli.altitudeAgl and heli.verticalSpeed and not heli.altitudeMsl, 'helicóptero: altura sobre suelo y velocidad vertical')
F.ok(not heli.cruise and not heli.nitro and not heli.seatbelt, 'helicóptero: sin funciones terrestres')
local forced = P.build('plane', { cruise = true, nitro = true, seatbelt = true })
F.ok(not forced.cruise and not forced.nitro and not forced.seatbelt, 'aeronave: ni forzando por modelo hay crucero/nitro/cinturón')
local bike = P.build('bicycle')
local anyOn = false
for _, key in ipairs(P.FEATURE_KEYS) do if bike[key] then anyOn = true end end
F.ok(not bike.hud and not anyOn, 'bicicleta: sin HUD y ninguna función activa')
F.ok(not bike.show.lights and not bike.show.indicators, 'bicicleta: sin testigos')
F.ok(not P.build('train').hud, 'tren: sin HUD')
F.ok(not P.build('bicycle', { cruise = true }).cruise, 'bicicleta: ni una excepción activa funciones sin hud=true')

Config.Features.cruise = false
F.ok(not P.build('car').cruise, 'interruptor global desactiva el crucero')
Config.Features.cruise = true
Config.Features.lights = false
local noLights = P.build('car')
F.ok(not noLights.lights and noLights.show.lights, 'luces propias desactivadas: el testigo sigue mostrando el estado real')
Config.Features.lights = true

F.section('Escala y unidades')
F.eq(P.scaleKmh({ maxSpeed = 300 }, 50), 300, 'escala fija por perfil/modelo')
F.eq(P.scaleKmh(car, 60), 260, 'auto: 60 m/s → 216 km/h × 1,15 → 260')
F.eq(P.scaleKmh(car, 10), 160, 'auto: limitada por autoMin')
F.eq(P.scaleKmh(car, 200), 360, 'auto: limitada por autoMax')
F.eq(P.scaleKmh(car, 0), 260, 'auto sin dato → fallbackMax')

F.section('Pedal (independiente de velocidad y RPM)')
F.eq(P.pedal(0.6, 3), 0.6, 'pedal en marcha adelante')
F.eq(P.pedal(-0.8, 3), 0, 'freno con marcha adelante no es acelerador')
F.eq(P.pedal(-0.5, 0), 0.5, 'marcha atrás: el pedal se reporta negativo')
F.eq(P.pedal(1.7, 2), 1, 'pedal limitado a 1')
F.eq(P.pedal(nil, 1), 0, 'sin dato → 0')

F.section('Salud del motor (rango oficial -4000…1000)')
F.eq(U.engineHealthPct(1000), 100, '1000 → 100 % (perfecto)')
F.eq(U.engineHealthPct(900), 90, 'daño leve: 900 → 90 %')
F.eq(U.engineHealthPct(650), 65, 'moderado: 650 → 65 % (empieza a perder gasolina)')
F.eq(U.engineHealthPct(300), 30, 'grave: 300 → 30 % (humea)')
F.eq(U.engineHealthPct(0), 0, '0 → 0 % (arde)')
F.eq(U.engineHealthPct(-4000), 0, '-4000 → 0 % (destruido)')
F.eq(U.engineHealthPct(1200), 100, 'por encima del máximo → 100 %')
F.eq(U.engineHealthPct(nil), nil, 'sin dato → nil')

F.section('Escala del HUD')
F.eq(CarHud.Settings.sanitize({ cluster = { scale = 0.5 } }).cluster.scale, 0.8, 'mínimo 80 %')
F.eq(CarHud.Settings.sanitize({ cluster = { scale = 2 } }).cluster.scale, 1.5, 'máximo 150 %')
F.eq(CarHud.Settings.sanitize({ cluster = { scale = 1.25 } }).cluster.scale, 1.25, 'valor intermedio conservado')
F.eq(CarHud.Settings.defaults().cluster.scale, 1, 'predeterminado 100 %')

F.section('Detector de accidentes vectorial (expulsión)')
local crash = CarHud.Crash.new(Config.Seatbelt.ejection)
-- Simula una secuencia a 60 fps: cada tramo { duración ms, vx, vy, colisión?, aire?, carrocería, salto de posición }
local function run(steps)
    crash:reset()
    local t, pos, last = 0, { x = 0, y = 0, z = 0 }, nil
    for _, st in ipairs(steps) do
        local frames = math.max(1, math.floor(st[1] / 16 + 0.5))
        for i = 1, frames do
            t = t + 16
            local vel = { x = st[2] / 3.6, y = st[3] / 3.6, z = st.vz or 0 }
            pos = { x = pos.x + vel.x * 0.016 + (i == 1 and st.jump or 0), y = pos.y + vel.y * 0.016, z = 0 }
            local r = crash:push({ t = t, vel = vel, pos = pos, collided = st.hit and i == 1 or false, body = st.body or 1000, inAir = st.air or false })
            if r.hit then return r end
            last = r
        end
    end
    return last
end
-- velocidades en km/h por componente (x = derecha, y = delante)
local r = run({ { 300, 0, 110 }, { 16, 0, 5, hit = true }, { 100, 0, 0 } })
F.ok(r.hit, 'frontal a 110 km/h → expulsión')
local out = CarHud.Crash.ejection(r, { horizontalForce = 1, verticalForce = 2 })
F.ok(out.dir.y > 0.99 and out.vel.y > 25, 'frontal: sale hacia delante con la inercia previa')

r = run({ { 300, 0, -90 }, { 16, 0, 0, hit = true }, { 100, 0, 0 } })
F.ok(r.hit, 'marcha atrás contra un obstáculo a 90 km/h → expulsión')
out = CarHud.Crash.ejection(r, { horizontalForce = 1, verticalForce = 2 })
F.ok(out.dir.y < -0.99 and out.vel.y < -20, 'marcha atrás: sale hacia atrás (no hacia el frontal)')

r = run({ { 300, 0, 0 }, { 16, 0, 85, hit = true }, { 100, 0, 80 } })
F.ok(r.hit, 'golpe recibido por detrás estando parado (0 → 85 km/h) → expulsión')
out = CarHud.Crash.ejection(r, { horizontalForce = 1, verticalForce = 2 })
F.ok(out.dir.y < -0.99 and math.abs(out.vel.y) < 0.5 and out.vel.z == 2, 'golpe por detrás: el ocupante conserva su inercia (queda atrás) + impulso vertical')

r = run({ { 300, 0, 50 }, { 16, 0, 125, hit = true }, { 100, 0, 120 } })
F.ok(r.hit, 'golpe recibido por detrás circulando (50 → 125 km/h) → expulsión (antes no: la velocidad subía)')

r = run({ { 300, 0, 0 }, { 16, 90, 0, hit = true }, { 100, 85, 0 } })
F.ok(r.hit, 'golpe lateral por la izquierda estando parado → expulsión')
out = CarHud.Crash.ejection(r, { horizontalForce = 1.2, verticalForce = 2 })
F.ok(out.dir.x < -0.99, 'lateral: sale por el lado del impacto')
r = run({ { 300, 0, 0 }, { 16, -90, 0, hit = true }, { 100, -85, 0 } })
F.ok(r.hit and CarHud.Crash.ejection(r, Config.Seatbelt.ejection).dir.x > 0.99, 'golpe lateral por la derecha → sale por la derecha')

r = run({ { 300, 0, 110 }, { 16, 50, 52, hit = true }, { 100, 50, 50 } })
F.ok(r.hit, 'impacto lateral circulando a 110 km/h (desvío brusco) → expulsión (antes no: la rapidez apenas bajaba)')
r = run({ { 300, 0, 110 }, { 16, 54, 36, hit = true }, { 100, 54, 36 } })
F.ok(r.hit, 'impacto diagonal → expulsión')
out = CarHud.Crash.ejection(r, Config.Seatbelt.ejection)
F.ok(out.dir.x < 0 and out.dir.y > 0, 'diagonal: dirección intermedia coherente con la inercia y el golpe')

-- Casos que no deben expulsar
r = run({ { 300, 0, 110 }, { 1200, 0, 70, hit = false } })
F.ok(not r.hit and r.reason == 'below_delta', 'frenada fuerte: descartada (' .. r.reason .. ')')
local turn = {}
for i = 0, 40 do
    local a = math.rad(i * 3)
    turn[#turn + 1] = { 30, 100 * math.sin(a), 100 * math.cos(a) }
end
r = run(turn)
F.ok(not r.hit and r.reason == 'below_delta', 'curva cerrada a 100 km/h: descartada')
local drift = {}
for i = 0, 50 do
    local a = math.rad(i * 2.2)
    drift[#drift + 1] = { 16, 70 * math.sin(a), 70 * math.cos(a) }
end
r = run(drift)
F.ok(not r.hit, 'derrape con giro de 110° a 70 km/h: descartado (' .. r.reason .. ')')
r = run({ { 300, 0, 120 }, { 300, 0, 120, air = true, vz = -12 }, { 16, 0, 60, hit = true }, { 100, 0, 60 } })
F.ok(not r.hit and r.reason == 'airborne', 'aterrizaje de un salto: descartado (airborne)')
r = run({ { 300, 0, 100 }, { 16, 0, 0, jump = 600 }, { 100, 0, 0 } })
F.ok(not r.hit and r.reason == 'teleport', 'teletransporte: descartado')
r = run({ { 300, 0, 110 }, { 16, 0, 0 }, { 100, 0, 0 } })
F.ok(not r.hit and r.reason == 'no_collision', 'parada brusca sin colisión (p. ej. un script): descartada')
r = run({ { 300, 0, 110 }, { 16, 0, 0, body = 940 }, { 100, 0, 0, body = 940 } })
F.ok(r.hit, 'sin evento de colisión pero con daño en la carrocería: cuenta como evidencia')
r = run({ { 300, 0, 200 }, { 16, 0, 155, hit = true }, { 100, 0, 155 } })
F.ok(not r.hit and r.reason == 'ratio', 'roce a 200 km/h (−45 km/h): descartado por relación')
r = run({ { 300, 0, 0 }, { 16, 0, 45, hit = true }, { 100, 0, 40 } })
F.ok(not r.hit and r.reason == 'min_speed', 'golpe leve por detrás (0 → 45 km/h): por debajo de la velocidad mínima')
local soft = Config.Seatbelt.ejection.minSpeed
Config.Seatbelt.ejection.minSpeed = 40
r = run({ { 300, 0, 0 }, { 16, 0, 45, hit = true }, { 100, 0, 40 } })
F.ok(r.hit, 'con la sensibilidad del administrador (40 km/h) el mismo golpe sí expulsa')
Config.Seatbelt.ejection.minSpeed = soft
r = run({ { 300, 0, 110 }, { 16, 0, 5, hit = true } })
local strong = CarHud.Crash.ejection(r, { horizontalForce = 2, verticalForce = 6 })
local weak = CarHud.Crash.ejection(r, { horizontalForce = 0.5, verticalForce = 0 })
F.ok(r.hit and strong.vel.y > weak.vel.y and strong.vel.z == 6 and weak.vel.z == 0, 'la fuerza (impulso) no cambia la detección y escala la salida')

F.section('Ajustes del jugador')
local S = CarHud.Settings
local d = S.sanitize(nil)
F.eq(d.unit, 'kmh', 'por defecto km/h')
F.eq(d.accent, '#FE3555', 'acento por defecto')
F.eq(d.values, false, 'valores numéricos desactivados por defecto')
local bad = S.sanitize({ unit = 'knots', accent = 'red', values = 'yes', volume = 9, modules = { rpm = false, hack = true }, cluster = { scale = 9, x = -3, y = 0.5 }, strip = { scale = 1.2 } })
F.eq(bad.unit, 'kmh', 'unidad inválida descartada')
F.eq(bad.accent, '#FE3555', 'color inválido descartado')
F.eq(bad.values, false, 'booleano inválido descartado')
F.eq(bad.volume, 1, 'volumen limitado a maxVolume')
F.eq(bad.modules.rpm, false, 'módulo válido aplicado')
F.eq(bad.modules.hack, nil, 'módulo desconocido descartado')
F.eq(bad.cluster.scale, 1.5, 'escala limitada a scaleMax')
F.eq(bad.cluster.x, 0, 'posición limitada al área visible')
F.eq(bad.strip, nil, 'la antigua franja se descarta (conjunto único)')
F.eq(bad.modules.turbo, nil, 'el módulo de turbo ya no existe en los ajustes')
F.eq(S.sanitize({ cluster = { scale = 'x' } }).cluster.scale, 1, 'escala inválida → por defecto')
F.eq(d.cluster.opacity, 1, 'opacidad del reloj por defecto 100 %')
local op = S.sanitize({ cluster = { opacity = 0.05 } })
F.eq(op.cluster.opacity, Config.Player.opacityMin, 'opacidad limitada a opacityMin')
F.eq(S.sanitize({ cluster = { opacity = 0.7 } }).cluster.opacity, 0.7, 'opacidad del conjunto')
F.eq(S.sanitize({ cluster = { opacity = 3 } }).cluster.opacity, 1, 'opacidad limitada a 100 %')
Config.Player.allowColor = false
Config.Player.maxVolume = 0.5
local restricted = S.sanitize({ accent = '#FF0000', volume = 0.9 })
F.eq(restricted.accent, '#FE3555', 'el jugador no salta la restricción de color')
F.eq(restricted.volume, 0.5, 'el jugador no supera el volumen máximo del servidor')
Config.Player.allowColor = true
Config.Player.maxVolume = 1.0
local roundtrip = S.sanitize(json.decode(json.encode(S.sanitize({ unit = 'mph', accent = '#41e7a3', cluster = { x = 0.8, y = 0.9, scale = 1.2 } }))))
F.ok(roundtrip.unit == 'mph' and roundtrip.accent == '#41E7A3' and roundtrip.cluster.x == 0.8 and roundtrip.cluster.scale == 1.2, 'guardar y cargar conserva las preferencias')

F.section('Nitro: contabilidad del servidor')
local now = 0
local store = CarHud.NitroStore.new(Config.Nitro, function() return now end)
F.ok(store:get('ABC') == nil, 'sin equipar por defecto')
F.ok(not store:start('ABC', 1), 'no se activa sin equipar')
store:equip('ABC', 100)
F.eq(store:get('ABC').amt, 100, 'equipado lleno')
F.eq(store:equip('X', 9999).cap, Config.Nitro.maxCapacity, 'capacidad limitada a maxCapacity')
F.ok(store:start('ABC', 1), 'activación')
F.ok(not store:start('ABC', 1), 'no se duplica la activación')
now = 2000
local amt, active = store:consume('ABC')
F.near(amt, 75, 1e-6, 'consumo 12,5/s durante 2 s')
F.ok(active, 'sigue activo')
now = 2500
store:stop('ABC')
F.near(store:get('ABC').amt, 68.75, 1e-6, 'al parar se descuenta el tramo final')
F.ok(not store:start('ABC', 1), 'enfriamiento entre activaciones')
now = 4500
F.ok(store:start('ABC', 1), 'tras el enfriamiento se reactiva')
now = 20000
amt, active = store:consume('ABC')
F.eq(amt, 0, 'se agota')
F.ok(not active and not store:isActive('ABC'), 'agotado → se desactiva solo')
now = 30000
F.ok(not store:start('ABC', 1), 'agotado no se activa')
F.ok(select(2, store:refill('ABC', -50)) == 'amount', 'recarga negativa rechazada')
store:refill('ABC', 40)
F.eq(store:get('ABC').amt, 40, 'recarga parcial')
store:refill('ABC')
F.eq(store:get('ABC').amt, 100, 'recarga completa')
store:equip('LOW', 100, 3)
F.ok(not store:start('LOW', 2), 'por debajo de minToActivate no se activa')
F.eq(#store:activeBy(1), 0, 'sin activos del jugador 1')
local copy = CarHud.NitroStore.new(Config.Nitro, function() return now end)
F.eq(copy:load(json.decode(json.encode(store:serialize()))), 3, 'persistencia: se cargan las matrículas guardadas')
F.eq(copy:load({ ['  abc '] = { cap = 50, amt = 999 }, bad = 'x' }), 1, 'persistencia: entradas inválidas descartadas')
F.eq(copy:get('ABC').amt, 50, 'persistencia: carga limitada a la capacidad')
F.ok(store:remove('ABC') and store:get('ABC') == nil, 'retirar nitro')

F.section('Idiomas (locales/*.json)')
F.eq(CarHud.Locale.lang, 'en', 'idioma inicial de la distribución: inglés')
F.eq(CarHud.T('key_nitro'), 'Nitro (hold)', 'texto del juego en inglés')
F.eq(CarHud.T('clave_inexistente'), 'clave_inexistente', 'clave ausente: se muestra la clave, sin error')
local en = json.decode(LoadResourceFile('vortexlabs_carhud', 'locales/en.json'))
local es = json.decode(LoadResourceFile('vortexlabs_carhud', 'locales/es.json'))
local function sameKeys(a, b)
    for k in pairs(a) do if b[k] == nil then return false, k end end
    for k in pairs(b) do if a[k] == nil then return false, k end end
    return true
end
local okGame, missGame = sameKeys(en.game, es.game)
local okUi, missUi = sameKeys(en.ui, es.ui)
F.ok(okGame and okUi, 'inglés y español tienen las mismas claves' .. ((missGame or missUi) and (' (falta ' .. tostring(missGame or missUi) .. ')') or ''))
Config.Locale = 'es'
dofile(FD_ROOT .. '/shared/locale.lua')
F.eq(CarHud.T('key_nitro'), es.game.key_nitro, 'Config.Locale = es: textos en español')
F.ok(CarHud.Locale.ui['settings.title'] == es.ui['settings.title'] and CarHud.Locale.fallback.ui['settings.title'] == en.ui['settings.title'], 'la NUI recibe español e inglés como respaldo')
es.game.key_nitro = nil
F.files['locales/es.json'] = json.encode(es)
dofile(FD_ROOT .. '/shared/locale.lua')
F.eq(CarHud.T('key_nitro'), 'Nitro (hold)', 'clave que falta en español: cae al inglés')
F.files['locales/es.json'] = nil
Config.Locale = 'fr'
dofile(FD_ROOT .. '/shared/locale.lua')
F.ok(CarHud.Locale.lang == 'en' and CarHud.T('key_nitro') == 'Nitro (hold)', 'idioma inexistente: inglés, con un aviso en consola')
Config.Locale = 'en'
dofile(FD_ROOT .. '/shared/locale.lua')

F.finish()
