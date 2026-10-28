-- Expulsión en el cliente completo: todos los tipos de impacto, con y sin
-- cinturón, posición de salida coherente y diagnóstico con permiso.
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
F.load(F.SHARED)
os, io = nil, nil
F.load(F.CLIENT)
F.nuiCall('ready')

local car = F.spawn({ model = 'sultan', class = 4, plate = 'CRASH' })
local v = F.vehicles[car]
local function board()
    F.pedState.ragdoll, F.pedState.damage = false, 0
    v.vel, v.speed, v.collided = { x = 0, y = 0, z = 0 }, 0, false
    F.enter(car, -1)
    F.run(700)
end
local function vec(kx, ky) return { x = kx / 3.6, y = ky / 3.6, z = 0 } end
-- De una velocidad (km/h por eje) a otra, con colisión en el fotograma del golpe.
local function impact(fromX, fromY, toX, toY)
    v.vel, v.collided = vec(fromX, fromY), false
    v.speed = math.sqrt(fromX ^ 2 + fromY ^ 2) / 3.6
    F.run(300)
    v.vel, v.collided = vec(toX, toY), true
    v.speed = math.sqrt(toX ^ 2 + toY ^ 2) / 3.6
    F.run(20)
    v.collided = false
    F.run(200)
end
local function ejected() return F.pedVehicle == 0 end

local cases = {
    { 'frontal a 110 km/h', 0, 110, 0, 0, function(p) return p.y > 2 end, 'por delante' },
    { 'marcha atrás contra un obstáculo a 90 km/h', 0, -90, 0, 0, function(p) return p.y < -2 end, 'por detrás' },
    { 'golpe recibido por detrás estando parado', 0, 0, 0, 85, function(p) return p.y < -2 end, 'por detrás' },
    { 'golpe recibido por la izquierda', 0, 0, 90, 0, function(p) return p.x < -1 end, 'por la izquierda' },
    { 'golpe recibido por la derecha', 0, 0, -90, 0, function(p) return p.x > 1 end, 'por la derecha' },
    { 'impacto diagonal circulando', 0, 110, 54, 36, function(p) return p.x < 0 and p.y > 0 end, 'en diagonal delantera izquierda' },
}

F.section('Sin cinturón: todos los tipos de impacto')
for _, c in ipairs(cases) do
    board()
    impact(c[2], c[3], c[4], c[5])
    F.ok(ejected(), c[1] .. ': expulsado')
    F.ok(ejected() and c[6](F.pedState.coords), c[1] .. ': aparece ' .. c[7] .. ' del vehículo')
    F.run(5500) -- protección entre expulsiones
end

F.section('Con cinturón: ningún impacto expulsa')
for _, c in ipairs(cases) do
    board()
    F.command('fcarhud_seatbelt') F.run(50)
    impact(c[2], c[3], c[4], c[5])
    F.ok(not ejected(), c[1] .. ': no expulsa con el cinturón')
    F.command('fcarhud_seatbelt') F.run(50)
    F.exitVehicle() F.run(400)
end

F.section('Sin falsos positivos dentro del juego simulado')
board()
for i = 0, 40 do
    local a = math.rad(i * 3)
    v.vel, v.collided = vec(100 * math.sin(a), 100 * math.cos(a)), false
    F.run(32)
end
F.ok(not ejected(), 'curva cerrada a 100 km/h sin cinturón: no expulsa')
v.vel = vec(0, 110) F.run(300)
for kmh = 110, 0, -6 do v.vel = vec(0, kmh) F.run(48) end
F.ok(not ejected(), 'frenada a fondo desde 110 km/h: no expulsa')
v.vel = vec(0, 120) F.run(300)
v.inAir = true F.run(400)
v.inAir = false v.vel, v.collided = vec(0, 50), true F.run(20) v.collided = false F.run(200)
F.ok(not ejected(), 'aterrizaje de un salto: no expulsa')

F.section('Diagnóstico (/carhudcrash)')
F.command('carhudcrash')
F.eq(F.serverEvents[#F.serverEvents].name, 'vortexlabs_carhud:admin:crashdiag', 'el comando pide permiso al servidor')
F.eq(F.lastNui('crashDiag'), nil, 'sin respuesta del servidor no se activa')
F.netEvent(nil, 'vortexlabs_carhud:crashdiag', true)
F.run(300)
local diag = F.lastNui('crashDiag')
F.ok(diag and diag.data and diag.data.dv ~= nil and diag.data.samples and #diag.data.samples > 0, 'muestra las muestras de velocidad y la variación')
F.command('fcarhud_seatbelt') F.run(50)
impact(0, 110, 0, 0)
diag = F.lastNui('crashDiag')
F.ok(not ejected() and diag.data.decision and diag.data.decision.reason == 'belted', 'abrochado: impacto detectado y descartado con motivo «belted»')
local logged = false
for _, line in ipairs(F.prints) do if line:find('crash: belted') then logged = true end end
F.ok(logged, 'la decisión queda también en la consola F8')
F.ok(diag.data.decision.evidence == true and diag.data.decision.dv >= 100, 'la decisión guarda la evidencia de colisión y el Δv del impacto')
F.command('fcarhud_seatbelt') F.run(50)
v.vel, v.collided = vec(0, 30), false F.run(400)
v.vel = vec(0, 0) F.run(20) F.run(200)
diag = F.lastNui('crashDiag')
F.ok(diag.data.reason == 'ratio' or diag.data.reason == 'min_speed' or diag.data.reason == 'below_delta' or diag.data.reason == 'no_collision', 'parada sin colisión a baja velocidad: descartada con su motivo (' .. tostring(diag.data.reason) .. ')')
F.netEvent(nil, 'vortexlabs_carhud:crashdiag', true)
F.eq(F.lastNui('crashDiag').data, false, 'segunda autorización: se desactiva')

F.finish()
