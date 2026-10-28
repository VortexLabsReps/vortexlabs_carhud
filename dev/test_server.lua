-- Simulación del servidor: nitro validado, consumo, statebag protegido,
-- comando de administración, permisos por framework y persistencia.
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
F.files['data/nitro.json'] = '{"OLD 1":{"cap":80,"amt":20}}'
F.load(F.SHARED)
F.load(F.SERVER)

local STATE = 'fcarhud_nitro'
local DRIVER, OTHER = 1, 2
F.playerPeds[DRIVER] = 11
F.playerPeds[OTHER] = 12

local car = F.spawn({ model = 'sultan', plate = 'vxlb 01 ', type = 'automobile' })
local v = F.vehicles[car]
v.seats[-1] = 11
v.seats[0] = 12
local function state() return Entity(car).state[STATE] end
local function lastClient() return F.clientEvents[#F.clientEvents] end
local function start(src, net) F.run(250) F.netEvent(src, 'vortexlabs_carhud:nitro:start', net) end

F.section('Equipamiento')
F.netEvent(DRIVER, 'vortexlabs_carhud:nitro:sync', v.net)
F.eq(state(), nil, 'sin nitro: no se publica nada')
start(DRIVER, v.net)
F.eq(state(), nil, 'sin nitro: la activación se rechaza')
F.ok(F.ownExports.EquipNitro(car, 100), 'export EquipNitro')
F.ok(state() and state().amt == 100 and state().cap == 100 and state().on == false, 'statebag publicado por el servidor')
F.eq(F.ownExports.GetNitro(car).amount, 100, 'export GetNitro')
F.eq(F.ownExports.GetNitro('VXLB 01').capacity, 100, 'GetNitro por matrícula normalizada')
local netNames = {}
for name in pairs(F.handlers) do if name:find('^vortexlabs_carhud:nitro:') then netNames[#netNames + 1] = name end end
table.sort(netNames)
F.eq(table.concat(netNames, ','), 'vortexlabs_carhud:nitro:start,vortexlabs_carhud:nitro:stop,vortexlabs_carhud:nitro:sync', 'no existe ningún evento de cliente para recargar o equipar')

F.section('Activación y consumo')
start(OTHER, v.net)
F.eq(state().on, false, 'un pasajero no puede activarlo')
start(DRIVER, 999)
F.eq(state().on, false, 'netId inválido: ignorado')
start(DRIVER, v.net)
F.eq(state().on, true, 'el conductor lo activa')
F.run(2000)
F.near(state().amt, 75, 3.2, 'consumo controlado por el servidor (≈12,5/s, publicado cada 250 ms)')
Entity(car).state:set(STATE, { amt = 999, cap = 999, on = true }, true)
F.run(50)
F.ok(state().amt < 100 and state().cap == 100, 'un cliente no puede reescribir la carga (se restablece)')
F.netEvent(DRIVER, 'vortexlabs_carhud:nitro:stop')
F.eq(state().on, false, 'parar')
local afterStop = state().amt
F.run(1000)
F.eq(state().amt, afterStop, 'parado no consume')
start(DRIVER, v.net)
F.eq(state().on, false, 'enfriamiento tras parar')
F.run(1600)
start(DRIVER, v.net)
F.eq(state().on, true, 'reactivación tras el enfriamiento')
start(DRIVER, v.net)
F.eq(state().on, true, 'activaciones repetidas limitadas sin efectos')
F.run(10000)
F.eq(state().amt, 0, 'se agota')
F.eq(state().on, false, 'agotado: se desactiva solo')

F.section('Condiciones que detienen el nitro')
F.ownExports.RefillNitro(car)
F.eq(state().amt, 100, 'recarga completa por export')
F.run(1600)
start(DRIVER, v.net)
v.seats[-1] = nil
v.seats[1] = 11
F.run(300)
F.eq(state().on, false, 'el conductor deja el asiento: se detiene')
v.seats[1], v.seats[-1] = nil, 11
F.run(1600)
start(DRIVER, v.net)
v.engineOn = false
F.run(300)
F.eq(state().on, false, 'motor apagado: se detiene')
v.engineOn = true
F.run(1600)
start(DRIVER, v.net)
F.netEvent(DRIVER, 'playerDropped')
F.eq(state().on, false, 'el jugador se desconecta: se detiene')
F.run(1600)
start(DRIVER, v.net)
local savedVehicle = F.vehicles[car]
F.vehicles[car] = nil
local okRun = pcall(F.run, 300)
F.vehicles[car] = savedVehicle
F.ok(okRun, "vehículo eliminado durante el uso: el bucle de consumo sigue sin errores")
F.ok(not CarHud.NitroServer.get(car) or not CarHud.NitroServer.get(car).active, 'vehículo eliminado: activo retirado')

F.section('Categorías incompatibles')
local boat = F.spawn({ model = 'speeder', type = 'boat', plate = 'BOAT 1' })
F.vehicles[boat].seats[-1] = 11
F.ok(not F.ownExports.EquipNitro(boat, 100), 'embarcación: no se puede equipar')
local bmx = F.spawn({ model = 'bmx', type = 'bike', plate = 'BMX 1' })
F.ok(not F.ownExports.EquipNitro(bmx, 100), 'bicicleta (tipo bike): no se puede equipar')
local bati = F.spawn({ model = 'bati', type = 'bike', plate = 'BATI 1' })
F.ok(F.ownExports.EquipNitro(bati, 100), 'moto: sí se puede equipar')
local heli = F.spawn({ model = 'buzzard', type = 'heli', plate = 'HELI 1' })
F.ok(not F.ownExports.EquipNitro(heli, 100), 'helicóptero: no se puede equipar')

F.section('Comando de administración')
F.command('carhudnitro', OTHER, { 'equip' })
F.eq(lastClient().args[1], CarHud.T('nitro_no_permission'), 'sin permiso: rechazado')
F.aces['2:vortexlabs_carhud.admin'] = true
v.seats[0] = nil
local passenger = F.spawn({ model = 'sultan', plate = 'ADM 2' })
F.vehicles[passenger].seats[-1] = 12
F.pedVehicle = 0
GetVehiclePedIsIn = function(ped) for h, veh in pairs(F.vehicles) do for _, p in pairs(veh.seats) do if p == ped then return h end end end return 0 end
F.command('carhudnitro', OTHER, { 'equip', '50' })
F.ok(lastClient().args[1]:find('ADM 2') ~= nil, 'con ACE vortexlabs_carhud.admin: equipado')
F.eq(F.ownExports.GetNitro('ADM 2').capacity, 50, 'capacidad indicada')
F.command('carhudnitro', OTHER, { 'refill', '-20' })
F.eq(F.ownExports.GetNitro('ADM 2').amount, 50, 'recarga negativa por comando: rechazada')
F.command('carhudnitro', 0, { 'remove', '2' })
F.eq(F.ownExports.GetNitro('ADM 2'), nil, 'consola con id de jugador: retirado')
F.command('carhudnitro', 0, { 'equip' })
F.ok(F.prints[#F.prints]:find('carhudnitro') ~= nil, 'consola sin id: muestra el uso')

F.section('Permisos por framework')
F.aces = {}
F.eq(CarHud.Framework.isAdmin(OTHER), false, 'standalone sin ACE: no es admin')
F.resources['qbx_core'] = 'started'
CarHud.Framework.refresh()
F.aces['2:admin'] = true
F.eq(CarHud.Framework.isAdmin(OTHER), true, 'Qbox: grupo admin por ACE')
F.aces = {}
F.resources['qbx_core'] = nil
F.resources['es_extended'] = 'started'
F.extExports['es_extended'] = { getSharedObject = function() return { GetPlayerFromId = function() return { getGroup = function() return 'admin' end } end } end }
CarHud.Framework.refresh()
F.eq(CarHud.Framework.isAdmin(OTHER), true, 'ESX: grupo admin')
F.extExports['es_extended'] = { getSharedObject = function() error('reiniciando') end }
F.eq(CarHud.Framework.isAdmin(OTHER), false, 'ESX reiniciándose: sin error, sin permiso')
F.resources['es_extended'] = nil
F.resources['qb-core'] = 'started'
F.extExports['qb-core'] = { GetCoreObject = function() return { Functions = { HasPermission = function(_, group) return group == 'god' end } } end }
CarHud.Framework.refresh()
F.eq(CarHud.Framework.isAdmin(OTHER), true, 'QBCore: HasPermission')
F.resources['qb-core'] = nil
CarHud.Framework.refresh()

F.section('Persistencia y parada')
F.eq(F.ownExports.GetNitro('OLD 1').amount, 20, 'carga guardada al iniciar')
F.ownExports.RefillNitro(bati)
F.vehicles[bati].seats[-1] = 11
F.playerPeds[DRIVER] = 11
start(DRIVER, F.vehicles[bati].net)
F.eq(Entity(bati).state[STATE].on, true, 'activo antes de parar el recurso')
F.stopResource('vortexlabs_carhud')
F.eq(Entity(bati).state[STATE].on, false, 'al parar el recurso: ningún nitro queda activo')
local saved = json.decode(F.files['data/nitro.json'])
F.ok(saved['BATI 1'] and saved['VXLB 01'] and saved['OLD 1'], 'al parar se guarda por matrícula')
F.ok(saved['ADM 2'] == nil, 'lo retirado no se guarda')

F.finish()
