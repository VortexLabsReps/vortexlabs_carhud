-- /carhudadmin (servidor): permisos en cada operación, validación atómica de
-- tipos y límites, persistencia en data/admin.json y difusión por GlobalState.
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
F.files['data/nitro.json'] = '{}'
F.load(F.SHARED)
F.load(F.SERVER)

local A = CarHud.Admin
local ADMIN, PLAYER = 1, 2
F.aces['1:vortexlabs_carhud.admin'] = true

local function clientEvents(name, target)
    local out = {}
    for _, e in ipairs(F.clientEvents) do
        if e.name == name and (target == nil or e.target == target) then out[#out + 1] = e end
    end
    return out
end
local function lastResult(target)
    local list = clientEvents('vortexlabs_carhud:admin:result', target)
    return list[#list] and list[#list].args[1]
end
local function save(src, changes) F.run(1100) F.netEvent(src, 'vortexlabs_carhud:admin:save', changes) return lastResult(src) end

F.section('Esquema y validación (compartido)')
F.eq(A.validate('Seatbelt.ejection.minSpeed', 90), 90, 'número dentro de límites')
F.eq(select(2, A.validate('Seatbelt.ejection.minSpeed', 500)), 'range', 'número fuera de límites: rechazado')
F.eq(select(2, A.validate('Seatbelt.ejection.minSpeed', '90')), 'type', 'texto en un campo numérico: rechazado')
F.eq(select(2, A.validate('Seatbelt.ejection.window', 120.5)), 'int', 'decimal en un campo entero: rechazado')
F.eq(select(2, A.validate('Seatbelt.ejection.enabled', 'true')), 'type', 'booleano como texto: rechazado')
F.eq(A.validate('Engine.key', 'j'), 'J', 'tecla normalizada a mayúsculas')
F.eq(select(2, A.validate('Engine.key', 'ZZ')), 'key', 'tecla inexistente: rechazada')
F.eq(select(2, A.validate('Seatbelt.ejection.categories', { 'car', 'bicycle' })), 'option', 'categoría no admitida (bicicleta): rechazada')
F.eq(table.concat(A.validate('Seatbelt.ejection.categories', { 'heli', 'car', 'car' }), ','), 'car,heli', 'lista sin duplicados y en orden estable')
F.eq(table.concat(A.validate('Seatbelt.ejection.allowModels', { ' Sultan ', 'sultan', 'adder' }), ','), 'sultan,adder', 'modelos normalizados')
F.eq(select(2, A.validate('Seatbelt.ejection.allowModels', { 'mal;nombre' })), 'model', 'modelo con caracteres no válidos: rechazado')
F.eq(select(2, A.validate('Config.Engine.authorize', 'none')), 'unknown', 'los permisos de llaves no son editables')
F.eq(select(2, A.validate('Categories.bicycle.hud', true)), 'unknown', 'la matriz de categorías no es editable')
F.eq(table.concat(A.defaults()['Seatbelt.ejection.categories'], ','), 'car', 'expulsión por defecto solo en automóviles')
F.ok(A.ejectionAllowed('car', GetHashKey('sultan'), GetHashKey), 'por defecto: automóvil sí')
for _, c in ipairs({ 'motorcycle', 'bicycle', 'boat', 'plane', 'heli' }) do
    F.ok(not A.ejectionAllowed(c, GetHashKey('x'), GetHashKey), 'por defecto: ' .. c .. ' no')
end

F.section('Permisos (servidor)')
F.netEvent(PLAYER, 'vortexlabs_carhud:admin:open')
F.eq(#clientEvents('vortexlabs_carhud:admin:data', PLAYER), 0, 'sin permiso: no recibe datos del menú')
F.eq(clientEvents('vortexlabs_carhud:notify', PLAYER)[1].args[1], CarHud.T('admin_no_permission'), 'sin permiso: aviso')
F.netEvent(ADMIN, 'vortexlabs_carhud:admin:open')
local data = clientEvents('vortexlabs_carhud:admin:data', ADMIN)[1]
F.ok(data and data.args[1].values['Seatbelt.ejection.minSpeed'] == 75 and data.args[1].defaults ~= nil, 'con ACE vortexlabs_carhud.admin: valores y predeterminados')
local r = save(PLAYER, { ['Seatbelt.ejection.minSpeed'] = 90 })
F.ok(r and not r.ok and r.errors[1].error == 'permission', 'guardar sin permiso: rechazado en el servidor (ocultar el menú no basta)')
F.eq(Config.Seatbelt.ejection.minSpeed, 75, 'sin permiso: nada cambia')

F.section('Diagnóstico de expulsión (permiso)')
F.run(600)
F.netEvent(PLAYER, 'vortexlabs_carhud:admin:crashdiag')
F.eq(#clientEvents('vortexlabs_carhud:crashdiag', PLAYER), 0, 'sin permiso: el diagnóstico no se autoriza')
F.netEvent(ADMIN, 'vortexlabs_carhud:admin:crashdiag')
F.eq(clientEvents('vortexlabs_carhud:crashdiag', ADMIN)[1].args[1], true, 'administrador: diagnóstico autorizado')

F.section('Guardado atómico con validación')
r = save(ADMIN, { ['Seatbelt.ejection.minSpeed'] = 90, ['Seatbelt.ejection.window'] = 5, ['Engine.key'] = 'ZZ', ['Inventado'] = 1 })
F.ok(r and not r.ok and #r.errors == 3, 'tres errores detectados (límite, tecla, desconocido)')
F.eq(Config.Seatbelt.ejection.minSpeed, 75, 'con un solo error no se aplica ningún cambio')
r = save(ADMIN, { ['Nitro.defaultCapacity'] = 500, ['Nitro.maxCapacity'] = 200 })
F.ok(r and not r.ok and r.errors[1].id == 'Nitro.defaultCapacity', 'comprobación cruzada: capacidad inicial ≤ máxima')
r = save(ADMIN, {
    ['Seatbelt.ejection.minSpeed'] = 90,
    ['Seatbelt.ejection.horizontalForce'] = 1.3,
    ['Seatbelt.ejection.verticalForce'] = 4,
    ['Seatbelt.ejection.categories'] = { 'car', 'motorcycle' },
    ['Nitro.consumption'] = 25,
    ['Cruise.minSpeed'] = 40,
    ['Lights.key'] = 'j',
    ['Features.cruise'] = false,
})
F.ok(r and r.ok and r.changed == 8, 'cambios válidos guardados')
F.ok(Config.Seatbelt.ejection.minSpeed == 90 and Config.Seatbelt.ejection.horizontalForce == 1.3 and Config.Lights.key == 'J', 'aplicados en el servidor')
local state = GlobalState.fcarhud_admin
F.ok(state and state.values['Cruise.minSpeed'] == 40 and state.values['Features.cruise'] == false, 'difundidos a los jugadores (GlobalState)')
local file = json.decode(F.files['data/admin.json'])
F.ok(file['Seatbelt.ejection.minSpeed'] == 90 and file['Nitro.consumption'] == 25, 'persistidos en data/admin.json')
F.eq(file['Seatbelt.ejection.ragdoll'], nil, 'solo se guardan los valores distintos del predeterminado')

F.section('El nitro usa los nuevos parámetros sin reiniciar')
local car = F.spawn({ model = 'sultan', plate = 'ADM 1' })
F.vehicles[car].seats[-1] = 11
F.playerPeds[ADMIN] = 11
F.ownExports.EquipNitro(car, 100)
F.run(250)
F.netEvent(ADMIN, 'vortexlabs_carhud:nitro:start', F.vehicles[car].net)
F.run(2000)
F.netEvent(ADMIN, 'vortexlabs_carhud:nitro:stop')
F.near(Entity(car).state.fcarhud_nitro.amt, 50, 4, 'consumo 25/s aplicado (2 s → ~50)')

F.section('Restaurar predeterminados')
local defaultsBack = {}
for _, field in ipairs(A.FIELDS) do defaultsBack[field.id] = A.defaults()[field.id] end
r = save(ADMIN, defaultsBack)
F.ok(r and r.ok, 'guardar los predeterminados')
F.eq(Config.Seatbelt.ejection.minSpeed, 75, 'valores de config.lua restaurados')
F.eq(next(json.decode(F.files['data/admin.json']) or {}), nil, 'archivo de cambios vacío')
F.eq(next(GlobalState.fcarhud_admin.values), nil, 'jugadores informados de la restauración')

F.section('Límite de frecuencia')
F.run(1100)
F.netEvent(ADMIN, 'vortexlabs_carhud:admin:save', { ['Cruise.minSpeed'] = 35 })
F.netEvent(ADMIN, 'vortexlabs_carhud:admin:save', { ['Cruise.minSpeed'] = 45 })
F.eq(lastResult(ADMIN).errors and lastResult(ADMIN).errors[1].error, 'rate', 'guardados seguidos: el segundo se rechaza')
F.eq(Config.Cruise.minSpeed, 35, 'solo se aplicó el primero')

F.finish()
