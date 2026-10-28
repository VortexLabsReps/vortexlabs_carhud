-- Nitro (servidor): equipamiento, carga, activación y consumo validados aquí.
-- El estado se publica en el statebag del vehículo (solo lectura para el HUD).
-- Ningún evento de cliente puede añadir carga: equipar y recargar solo es
-- posible con el comando de administración o con los exports de servidor.
local Util = CarHud.Util
local cfg = Config.Nitro
local STATE_KEY = 'fcarhud_nitro'
local DATA_FILE = 'data/nitro.json'
local RESOURCE = GetCurrentResourceName()

local store = CarHud.NitroStore.new(cfg, GetGameTimer)
local entities = {}   -- plate → entidad publicada
local published = {}  -- entidad → clave del último valor publicado
local rate = {}       -- [source][evento] → último uso (ms)

local BICYCLES = {}
for _, name in ipairs({ 'bmx', 'cruiser', 'fixter', 'scorcher', 'tribike', 'tribike2', 'tribike3', 'inductor', 'inductor2' }) do
    BICYCLES[GetHashKey(name)] = true
end
CarHud.Profiles.indexModels(GetHashKey)

------------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------------
local function limited(source, event, interval)
    local now = GetGameTimer()
    rate[source] = rate[source] or {}
    if rate[source][event] and now - rate[source][event] < interval then return true end
    rate[source][event] = now
    return false
end

local function vehicleFromNet(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return nil end
    return entity
end

local function plateOf(entity)
    return Util.normalizePlate(GetVehicleNumberPlateText(entity))
end

-- Categoría desde el servidor (GetVehicleType) + excepciones por modelo.
local TYPE_CATEGORY = {
    automobile = 'car', amphibious_automobile = 'car', trailer = 'car',
    bike = 'motorcycle', quadbike = 'motorcycle', amphibious_quadbike = 'motorcycle',
    boat = 'boat', submarine = 'boat', heli = 'heli', plane = 'plane', blimp = 'plane', train = 'train',
}

local function categoryOf(entity)
    local model = GetEntityModel(entity)
    local override = CarHud.Profiles.modelOverride(model)
    if override and override.category then return override.category, override end
    if BICYCLES[model] then return 'bicycle', override end
    return TYPE_CATEGORY[GetVehicleType(entity)] or 'car', override
end

local function nitroAllowed(entity)
    if not Config.Features.nitro then return false end
    local category, override = categoryOf(entity)
    local profile = CarHud.Profiles.build(category, override)
    return profile.nitro == true
end

local function isDriver(source, entity)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and GetPedInVehicleSeat(entity, -1) == ped
end

------------------------------------------------------------------------------
-- Publicación en el statebag
------------------------------------------------------------------------------
local function publish(plate, entity)
    entity = entity or entities[plate]
    if not entity or not DoesEntityExist(entity) then return end
    entities[plate] = entity
    local entry = store:get(plate)
    local value = entry and { amt = Util.round(entry.amt, 1), cap = Util.round(entry.cap, 1), on = store:isActive(plate) } or nil
    published[entity] = value and ('%.1f|%.1f|%s'):format(value.amt, value.cap, tostring(value.on)) or 'none'
    Entity(entity).state:set(STATE_KEY, value, true)
end

-- Un cliente no puede reescribir el estado: se restablece lo publicado.
AddStateBagChangeHandler(STATE_KEY, nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or published[entity] == nil then return end
    local key = type(value) == 'table' and ('%.1f|%.1f|%s'):format(tonumber(value.amt) or -1, tonumber(value.cap) or -1, tostring(value.on)) or 'none'
    if key ~= published[entity] then
        for plate, known in pairs(entities) do
            if known == entity then SetTimeout(0, function() publish(plate, entity) end) return end
        end
    end
end)

local function stopActive(plate)
    if store:stop(plate) then publish(plate) end
end

------------------------------------------------------------------------------
-- Persistencia (por matrícula, sin base de datos)
------------------------------------------------------------------------------
local function save()
    if not cfg.persist or not store.dirty then return end
    store.dirty = false
    SaveResourceFile(RESOURCE, DATA_FILE, json.encode(store:serialize()), -1)
end

if cfg.persist then
    local raw = LoadResourceFile(RESOURCE, DATA_FILE)
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok then store:load(data) end
    end
    store.dirty = false
end

------------------------------------------------------------------------------
-- Bucle de consumo: cada 250 ms. Sin nitro activo solo recorre una tabla
-- vacía; así una activación nunca espera más de un tick a ser vigilada.
------------------------------------------------------------------------------
CreateThread(function()
    local saveTimer = 0
    while true do
        for plate, run in pairs(store.active) do
            local entity = entities[plate]
            local valid = entity and DoesEntityExist(entity) and isDriver(run.owner, entity)
                and not (GetIsVehicleEngineRunning and not GetIsVehicleEngineRunning(entity))
            if not valid then
                stopActive(plate)
            else
                store:consume(plate)
                publish(plate)
            end
        end
        saveTimer = saveTimer + 250
        if saveTimer >= 10000 then
            saveTimer = 0
            save()
        end
        Wait(250)
    end
end)

------------------------------------------------------------------------------
-- Eventos de cliente (solo piden; el servidor decide)
------------------------------------------------------------------------------
RegisterNetEvent('vortexlabs_carhud:nitro:sync', function(netId)
    local source = source
    if limited(source, 'sync', 1000) then return end
    local entity = vehicleFromNet(netId)
    if not entity or not isDriver(source, entity) then return end
    local plate = plateOf(entity)
    if not plate then return end
    if store:get(plate) then
        publish(plate, entity)
    elseif Entity(entity).state[STATE_KEY] ~= nil then
        Entity(entity).state:set(STATE_KEY, nil, true)
    end
end)

RegisterNetEvent('vortexlabs_carhud:nitro:start', function(netId)
    local source = source
    if limited(source, 'start', 200) then return end
    local entity = vehicleFromNet(netId)
    if not entity or not isDriver(source, entity) or not nitroAllowed(entity) then return end
    if GetIsVehicleEngineRunning and not GetIsVehicleEngineRunning(entity) then return end
    local plate = plateOf(entity)
    if not plate then return end
    entities[plate] = entity
    if store:start(plate, source) then publish(plate, entity) end
end)

RegisterNetEvent('vortexlabs_carhud:nitro:stop', function()
    local source = source
    for _, plate in ipairs(store:activeBy(source)) do stopActive(plate) end
end)

AddEventHandler('playerDropped', function()
    local source = source
    for _, plate in ipairs(store:activeBy(source)) do stopActive(plate) end
    rate[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for plate in pairs(store.active) do
        store:stop(plate)
        local entity = entities[plate]
        if entity and DoesEntityExist(entity) then
            local entry = store:get(plate)
            Entity(entity).state:set(STATE_KEY, entry and { amt = Util.round(entry.amt, 1), cap = entry.cap, on = false } or nil, true)
        end
    end
    store.dirty = true
    save()
end)

------------------------------------------------------------------------------
-- API de servidor: vehicle = entidad o matrícula.
------------------------------------------------------------------------------
local function resolve(vehicle)
    if type(vehicle) == 'string' then
        local plate = Util.normalizePlate(vehicle)
        return plate, entities[plate]
    end
    local entity = tonumber(vehicle)
    if entity and DoesEntityExist(entity) and GetEntityType(entity) == 2 then
        return plateOf(entity), entity
    end
    return nil, nil
end

local Nitro = {}

function Nitro.equip(vehicle, capacity, amount)
    local plate, entity = resolve(vehicle)
    if not plate then return nil, 'vehicle' end
    if entity and not nitroAllowed(entity) then return nil, 'category' end
    local entry = store:equip(plate, capacity, amount)
    publish(plate, entity)
    return entry
end

function Nitro.refill(vehicle, amount)
    local plate, entity = resolve(vehicle)
    if not plate then return nil, 'vehicle' end
    local entry, err = store:refill(plate, amount)
    if entry then publish(plate, entity) end
    return entry, err
end

function Nitro.remove(vehicle)
    local plate, entity = resolve(vehicle)
    if not plate then return false end
    local removed = store:remove(plate)
    entity = entity or entities[plate]
    if entity and DoesEntityExist(entity) then Entity(entity).state:set(STATE_KEY, nil, true) end
    if entity then published[entity] = nil end
    entities[plate] = nil
    return removed
end

function Nitro.get(vehicle)
    local plate = resolve(vehicle)
    local entry = store:get(plate)
    if not entry then return nil end
    return { plate = plate, capacity = entry.cap, amount = entry.amt, active = store:isActive(plate) }
end

exports('EquipNitro', function(vehicle, capacity, amount) return Nitro.equip(vehicle, capacity, amount) ~= nil end)
exports('RefillNitro', function(vehicle, amount) return Nitro.refill(vehicle, amount) ~= nil end)
exports('RemoveNitro', function(vehicle) return Nitro.remove(vehicle) end)
exports('GetNitro', function(vehicle) return Nitro.get(vehicle) end)

------------------------------------------------------------------------------
-- Comando de administración (protegido por permisos)
--   Jugador: /carhudnitro equip [capacidad] | refill [cantidad] | remove | info
--   Consola: carhudnitro <acción> <id del jugador> [valor]
------------------------------------------------------------------------------
local function reply(source, text, kind)
    if source == 0 then print(('[vortexlabs_carhud] %s'):format(text)) return end
    TriggerClientEvent('vortexlabs_carhud:notify', source, text, kind or 'info')
end

RegisterCommand(cfg.command, function(source, args)
    if not Config.Features.nitro then return end
    if not CarHud.Framework.isAdmin(source) then
        return reply(source, CarHud.T('nitro_no_permission'), 'danger')
    end
    local action = args[1]
    local target, value = source, args[2]
    if source == 0 then target, value = tonumber(args[2]), args[3] end
    if not action or not target or target <= 0 and source == 0 then
        return reply(source, CarHud.T('nitro_usage', cfg.command), 'warn')
    end

    local ped = GetPlayerPed(target)
    local entity = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if entity == 0 then return reply(source, CarHud.T('nitro_no_vehicle'), 'warn') end
    local plate = plateOf(entity)
    if not plate then return reply(source, CarHud.T('nitro_no_vehicle'), 'warn') end
    entities[plate] = entity

    if action == 'equip' then
        local entry, err = Nitro.equip(entity, tonumber(value))
        if not entry then return reply(source, CarHud.T(err == 'category' and 'nitro_category' or 'nitro_no_vehicle'), 'warn') end
        reply(source, CarHud.T('nitro_equipped', plate, entry.amt, entry.cap))
    elseif action == 'refill' then
        local entry = Nitro.refill(entity, tonumber(value))
        if not entry then return reply(source, CarHud.T('nitro_none', plate), 'warn') end
        reply(source, CarHud.T('nitro_refilled', plate, entry.amt, entry.cap))
    elseif action == 'remove' then
        if not Nitro.remove(entity) then return reply(source, CarHud.T('nitro_none', plate), 'warn') end
        reply(source, CarHud.T('nitro_removed', plate))
    elseif action == 'info' then
        local entry = store:get(plate)
        if not entry then return reply(source, CarHud.T('nitro_none', plate), 'warn') end
        store:consume(plate)
        reply(source, CarHud.T('nitro_info', plate, entry.amt, entry.cap))
    else
        reply(source, CarHud.T('nitro_usage', cfg.command), 'warn')
    end
    save()
end, false)

CarHud.NitroServer = Nitro
