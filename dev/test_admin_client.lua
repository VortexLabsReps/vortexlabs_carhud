-- /carhudadmin (cliente): valores replicados al arrancar, cambios en caliente y
-- expulsión configurable (umbral y fuerza independientes, protección, categorías).
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
-- El servidor ya publicó cambios antes de que arranque el cliente.
GlobalState.fcarhud_admin = { rev = 3, values = { ['Engine.key'] = 'J', ['Cruise.minSpeed'] = 40, ['Engine.authorize'] = 'none' } }
F.load(F.SHARED)
os, io = nil, nil
F.load(F.CLIENT)
F.nuiCall('ready')

local function publish(values)
    GlobalState:set('fcarhud_admin', { rev = math.random(1000), values = values }, true)
    F.run(50)
end
local function lastSound()
    local m = F.lastNui('sound')
    return m and m.name
end

F.section('Arranque con ajustes del servidor')
F.eq(Config.Cruise.minSpeed, 40, 'valor replicado aplicado antes de usarse')
F.eq(F.keymaps['fcarhud_engine'].key, 'J', 'tecla predeterminada del servidor al registrar teclas')
F.eq(Config.Engine.authorize, 'auto', 'un valor no editable en el estado replicado se ignora')
F.ok(F.keymaps['fcarhud_cruise'] and F.keymaps['+fcarhud_nitro'], 'todas las teclas registradas (activables en caliente)')

F.section('Cambios en caliente')
local car = F.spawn({ model = 'sultan', class = 4, plate = 'CAR 1' })
local v = F.vehicles[car]
F.enter(car, -1)
F.run(700)
v.speed, v.gear = 72 / 3.6, 2
F.command('fcarhud_cruise') F.run(50)
F.ok(CarHud.Cruise.target > 0, 'crucero activo')
publish({ ['Features.cruise'] = false })
F.eq(CarHud.Cruise.target, 0, 'desactivar el crucero lo cancela al instante')
F.command('fcarhud_cruise') F.run(50)
F.eq(CarHud.Cruise.target, 0, 'desactivado: la tecla no hace nada')
F.eq(F.lastNui('profile').profile.telltales.cruise, false, 'el HUD retira el testigo del crucero')
publish({})
F.command('fcarhud_cruise') F.run(50)
F.ok(CarHud.Cruise.target > 0, 'reactivado sin reiniciar')
F.command('fcarhud_cruise') F.run(50)
publish({ ['Cruise.minSpeed'] = 100 })
F.command('fcarhud_cruise') F.run(50)
F.eq(CarHud.Cruise.target, 0, 'nueva velocidad mínima del crucero aplicada')
publish({})

F.section('Expulsión: umbral y fuerza independientes')
F.pedState.flags[32] = true
v.speed, v.vel = 0, { x = 0, y = 0, z = 0 }
publish({ ['Seatbelt.ejection.horizontalForce'] = 0.5, ['Seatbelt.ejection.verticalForce'] = 4, ['Seatbelt.ejection.damageEnabled'] = false })
local function crash(vehicle, kmh)
    local veh = F.vehicles[vehicle]
    veh.speed, veh.vel, veh.collided = kmh / 3.6, { x = kmh / 3.6, y = 0, z = 0 }, false
    F.run(100)
    veh.speed, veh.vel, veh.collided = 3 / 3.6, { x = 0.5, y = 0, z = 0 }, true
    F.run(100)
    veh.collided = false
end
crash(car, 108)
F.eq(F.pedVehicle, 0, 'choque a 108 km/h: expulsado')
F.near(F.pedState.vel.x, 15.25, 0.01, 'impulso horizontal = velocidad actual 0,5 + 0,5 × variación 29,5 m/s')
F.near(F.pedState.vel.z, 4, 0.01, 'impulso vertical = 4 m/s')
F.eq(F.pedState.damage, 0, 'daño adicional desactivado: sin daño')
F.run(400)
F.enter(car, -1) F.run(700)
crash(car, 108)
F.eq(F.pedVehicle, car, 'segundo choque dentro de la protección (5 s): no expulsa')
F.run(5000)
publish({ ['Seatbelt.ejection.minSpeed'] = 150 })
crash(car, 120)
F.eq(F.pedVehicle, car, 'umbral subido a 150 km/h: un choque a 120 no expulsa')
publish({ ['Seatbelt.ejection.minSpeed'] = 150, ['Seatbelt.ejection.horizontalForce'] = 2 })
crash(car, 120)
F.eq(F.pedVehicle, car, 'más fuerza no cambia el umbral')
publish({ ['Seatbelt.ejection.damage'] = 25 })
crash(car, 110)
F.eq(F.pedVehicle, 0, 'umbral restaurado: expulsa')
F.eq(F.pedState.damage, 25, 'daño adicional configurable')
F.run(400)

F.section('Categorías y modelos')
local bike = F.spawn({ model = 'bati', class = 8, kind = { bike = true } })
F.enter(bike, -1) F.run(700)
crash(bike, 120)
F.eq(F.pedVehicle, bike, 'moto: sin expulsión por defecto')
F.run(400)
publish({ ['Seatbelt.ejection.categories'] = { 'car', 'motorcycle' } })
F.run(6000)
crash(bike, 120)
F.eq(F.pedVehicle, 0, 'moto permitida por el administrador: expulsa (sin cinturón)')
F.run(400)
local bmx = F.spawn({ model = 'bmx', class = 13, kind = { bicycle = true } })
publish({ ['Seatbelt.ejection.categories'] = { 'car', 'motorcycle', 'boat', 'plane', 'heli' }, ['Seatbelt.ejection.allowModels'] = { 'bmx' } })
F.enter(bmx, -1) F.run(700)
F.run(6000)
crash(bmx, 120)
F.eq(F.pedVehicle, bmx, 'bicicleta: nunca, ni permitiendo el modelo')
F.exitVehicle() F.run(400)
publish({ ['Seatbelt.ejection.denyModels'] = { 'sultan' } })
F.enter(car, -1) F.run(700)
F.run(6000)
crash(car, 120)
F.eq(F.pedVehicle, car, 'modelo excluido: no expulsa')
publish({ ['Seatbelt.ejection.enabled'] = false })
crash(car, 120)
F.eq(F.pedVehicle, car, 'expulsión desactivada')
publish({})

F.section('Aviso sonoro y bloqueo de salida')
v.speed = 50 / 3.6
F.run(400)
F.eq(lastSound(), 'belt_warn', 'aviso sonoro activo por defecto')
F.nui = {}
publish({ ['Seatbelt.warnSound'] = false })
F.run(8000)
F.eq(lastSound(), nil, 'aviso sonoro desactivado: sin sonido (el testigo sigue)')
publish({ ['Seatbelt.lockExit'] = false })
F.command('fcarhud_seatbelt') F.run(50)
F.ok(F.disabled[75] ~= true, 'bloqueo de salida desactivado')
publish({})
F.run(50)
F.ok(F.disabled[75] == true, 'bloqueo de salida reactivado en caliente')
F.command('fcarhud_seatbelt') F.run(50)
v.speed = 0

F.section('Menú de administración (cliente)')
F.command('carhudadmin')
local openReq = 0
for _, e in ipairs(F.serverEvents) do if e.name == 'vortexlabs_carhud:admin:open' then openReq = openReq + 1 end end
F.eq(openReq, 1, '/carhudadmin solo pide al servidor; no abre nada por sí mismo')
F.ok(F.focus[1] ~= true, 'sin respuesta del servidor (sin permiso) no toma el foco')
F.netEvent(nil, 'vortexlabs_carhud:admin:data', { values = CarHud.Admin.current({}), defaults = CarHud.Admin.defaults() })
F.ok(F.focus[1] == true and F.lastNui('adminOpen') and #F.lastNui('adminOpen').fields == #CarHud.Admin.FIELDS, 'con datos del servidor: menú abierto con el esquema')
F.nuiCall('adminOpened')
local minBefore = Config.Cruise.minSpeed
F.nuiCall('adminSave', { values = { ['Cruise.minSpeed'] = 50 } })
local saveEv = F.serverEvents[#F.serverEvents]
F.ok(saveEv.name == 'vortexlabs_carhud:admin:save' and saveEv.args[1]['Cruise.minSpeed'] == 50, 'guardar se envía al servidor para validarlo')
F.eq(Config.Cruise.minSpeed, minBefore, 'el cliente no aplica nada hasta que el servidor lo publica')
F.nuiCall('adminClose')
F.ok(F.focus[1] == false, 'cerrar libera el foco')
F.netEvent(nil, 'vortexlabs_carhud:admin:data', { values = {}, defaults = {} })
F.run(2000)
F.ok(F.focus[1] == false, 'si la interfaz no confirma la apertura, se libera el foco')

F.finish()
